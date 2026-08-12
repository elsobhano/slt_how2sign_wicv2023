#!/bin/sh

#SBATCH --job-name="mc_i3dcfg"
#SBATCH --partition=cogvis-project,3090
#SBATCH --exclude=aisurrey36,aisurrey27
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --time=0-10:00:00
#SBATCH -o slurm_logs/slurm.%N.%j.out

source /mnt/fast/nobackup/users/sa04359/slt_how2sign_wicv2023/notify.sh

# Train the Tarrés translator on our full-train mean-conformer features
# (agcn_meanconf_w16_s2_new, window16/stride2, 256-d, NO val carve) using the
# EXACT I3D hyperparameters + logging. Only change vs the I3D config is
# model.feat_dim=256 (our features are 256-d; I3D's default is 1024).
# Validates on TEST every epoch under the "test" wandb tab, print samples off.

CONFIG=agcn_meanconf_new_i3dcfg.yaml
FEATURES=agcn_meanconf_w16_s2_new
WANDB_PROJECT=how2sign-slt-agcn
WANDB_NAME=agcn_meanconf_w16s2_new_i3dcfg

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
echo "Config: $CONFIG  Features: $FEATURES (mean-conformer w16 s2, 256-d, I3D cfg)" >> "$OUTPUT_FILE"
echo "Start Time: $(date)"                   >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"

notify_start
trap notify_timeout SIGTERM SIGINT

# No overrides — the config already carries the I3D hyperparameters (feat_dim=256).
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
