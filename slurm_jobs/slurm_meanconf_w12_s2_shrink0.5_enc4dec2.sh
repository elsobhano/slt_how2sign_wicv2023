#!/bin/sh

#SBATCH --job-name="mc_w12_s2_sh0.5_e4d2"
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

# --- best-config hyperparameters (the run that scored best) ---
ENC_LAYERS=4
DEC_LAYERS=2
LR=1e-3
DP=0.3
MAX_UPDATE=100000

# --- feature set for THIS job (mean-of-Conformer, window/stride variant) ---
TAG=w12_s2
FEATURES=agcn_meanconf_${TAG}

# --- fixed settings ---
CONFIG=agcn_signrep_6_3.yaml
WANDB_PROJECT=how2sign-slt-agcn
WANDB_NAME=agcn_meanconf_${TAG}_shrink0.5_enc4dec2

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
echo "Features: $FEATURES"                   >> "$OUTPUT_FILE"
echo "Start Time: $(date)"                   >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"

notify_start
trap notify_timeout SIGTERM SIGINT

apptainer exec "$IMAGE" bash -lc "
    python setup.py build_ext --inplace || exit 1
    SIGN_FEATS_PRELOAD=1 PYTHONPATH='$REPO' SAVE_DIR='$DATA' I3D_DIR='$DATA/$FEATURES' \
    WANDB_PROJECT='$WANDB_PROJECT' WANDB_NAME='$WANDB_NAME' \
    python -m fairseq_cli.hydra_train \
        --config-dir '$CONFIG_DIR' --config-name '$CONFIG' \
        optimization.lr=[$LR] optimization.max_update=$MAX_UPDATE \
        model.dropout=$DP model.attention_dropout=$DP model.activation_dropout=$DP \
        model.encoder_layers=$ENC_LAYERS model.decoder_layers=$DEC_LAYERS lr_scheduler.lr_shrink=0.5
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
