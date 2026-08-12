#!/bin/sh

#SBATCH --job-name="i3d_repro"
#SBATCH --partition=cogvis-project,3090
#SBATCH --exclude=aisurrey36
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --time=0-05:00:00
#SBATCH -o slurm_logs/slurm.%N.%j.out

source /mnt/fast/nobackup/users/sa04359/slt_how2sign_wicv2023/notify.sh

# Sanity check: reproduce the Tarrés et al. I3D How2Sign result (target ~BLEU 9.2).
# Runs the paper's FINAL I3D config as-is (no hyperparameter overrides).
# Requires the downloaded I3D features at $DATA/i3d_features (CSUC dataverse,
# doi:10.34810/data693) with the cvpr23.fairseq.i3d.{train,val,test}.how2sign.tsv
# manifests + per-split .npy. Vocab already lives under $DATA/vocab.

CONFIG=baseline_6_3_dp03_wd_2.yaml     # the paper's final I3D model
FEATURES=i3d_features
WANDB_PROJECT=how2sign-slt-agcn        # same board as your agcn runs, for comparison
WANDB_NAME=i3d_repro_6_3_dp03_wd2

# --- paths (auto-detect local vs cluster) ---
IMAGE=docker://container-registry.surrey.ac.uk/shared-containers/slt-how-2-sign
REPO="$PWD"
if   [ -d /projects/u6ei ];     then DATA=/projects/u6ei/sa04359/how2sign_wicv
elif [ -d /mnt/fast/nobackup ]; then DATA=/mnt/fast/nobackup/scratch4weeks/sa04359/how2sign_wicv
else                                 DATA=$REPO/data/how2sign
fi
CONFIG_DIR=examples/sign_language/config/wicv_cvpr23/i3d_best
export WANDB_API_KEY=1af8cc2a4ed95f2ba66c31d193caf3dd61c3a41f
mkdir -p slurm_logs outputs

OUTPUT_FILE="outputs/${WANDB_NAME}.out"
echo "========================================" > "$OUTPUT_FILE"
echo "SLURM Job ID: $SLURM_JOB_ID"           >> "$OUTPUT_FILE"
echo "Job Name: $SLURM_JOB_NAME"             >> "$OUTPUT_FILE"
echo "Node: $SLURM_NODELIST"                 >> "$OUTPUT_FILE"
echo "Config: $CONFIG  Features: $FEATURES (I3D repro, target ~BLEU 9.2)" >> "$OUTPUT_FILE"
echo "Start Time: $(date)"                   >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"

notify_start
trap notify_timeout SIGTERM SIGINT

# No overrides — run the paper's I3D config exactly as published.
apptainer exec "$IMAGE" bash -lc "
    python setup.py build_ext --inplace || exit 1
    SIGN_FEATS_PRELOAD=1 PYTHONPATH='$REPO' SAVE_DIR='$DATA' I3D_DIR='$DATA/$FEATURES' \
    WANDB_PROJECT='$WANDB_PROJECT' WANDB_NAME='$WANDB_NAME' \
    python -m fairseq_cli.hydra_train \
        --config-dir '$CONFIG_DIR' --config-name '$CONFIG'
" >> "$OUTPUT_FILE" 2>&1
EXIT_CODE=$?

echo "========================================" >> "$OUTPUT_FILE"
echo "End Time: $(date)"                       >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"

if [ $EXIT_CODE -eq 0 ]; then
    notify_success
else
    notify_failure "$OUTPUT_FILE" $EXIT_CODE
fi

exit $EXIT_CODE
