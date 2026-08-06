#!/bin/sh

#SBATCH --job-name="slt256"
#SBATCH --partition=cogvis-project,3090
#SBATCH --exclude=aisurrey36
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --time=0-02:00:00
#SBATCH -o slurm_logs/slurm.%N.%j.out

# --- paths --------------------------------------------------------------------
IMAGE=docker://container-registry.surrey.ac.uk/shared-containers/slt-how-2-sign
# REPO is auto-detected as the dir you `sbatch` from (no hardcoded path). It is
# kept ABSOLUTE on purpose: Hydra chdir's into its output dir mid-run, so the
# paths passed to fairseq below must be absolute or training breaks.
REPO="$PWD"                                      # the fairseq fork repo (= current dir)

# DATA auto-detects local vs cluster (mirrors configs/datasets.py SCRATCH logic):
# where agcn_features* + vocab live (and where checkpoints get written).
if   [ -d /projects/u6ei ];      then DATA=/projects/u6ei/sa04359/how2sign_wicv                 # Isambard
elif [ -d /mnt/fast/nobackup ];  then DATA=/mnt/fast/nobackup/scratch4weeks/sa04359/how2sign_wicv # Surrey cluster
else                                  DATA=$REPO/data/how2sign                                   # local
fi

# --- experiment (swap these to run a different variant) ---------------------
CONFIG=agcn_signrep_6_3.yaml                      # 256-d backbone, warm-restart cosine
RUN_NAME=agcn_signrep_6_3
FEATURES=agcn_features                            # use agcn_features_proj128 for the 128-d configs
# Examples:
#   CONFIG=agcn_signrep_6_3_proj128.yaml         RUN_NAME=agcn_proj128_6_3        FEATURES=agcn_features_proj128
#   CONFIG=agcn_signrep_6_3_cosine.yaml          RUN_NAME=agcn_signrep_6_3_cosine FEATURES=agcn_features
#   CONFIG=agcn_signrep_6_3_proj128_cosine.yaml  RUN_NAME=agcn_proj128_6_3_cosine FEATURES=agcn_features_proj128

export WANDB_API_KEY=1af8cc2a4ed95f2ba66c31d193caf3dd61c3a41f

# Relative is fine here — Hydra resolves --config-dir from the cwd at launch.
CONFIG_DIR=examples/sign_language/config/wicv_cvpr23/i3d_best
OUTPUT_FILE="outputs/slt_${RUN_NAME}.out"
mkdir -p outputs slurm_logs

echo "========================================" > "$OUTPUT_FILE"
echo "SLURM Job ID: $SLURM_JOB_ID"   >> "$OUTPUT_FILE"
echo "Node: $SLURM_NODELIST"         >> "$OUTPUT_FILE"
echo "Config: $CONFIG  Run: $RUN_NAME" >> "$OUTPUT_FILE"
echo "Start Time: $(date)"           >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"

apptainer exec "$IMAGE" bash -lc "
        python setup.py build_ext --inplace &&
        SIGN_FEATS_PRELOAD=1 PYTHONPATH='$REPO' \
        SAVE_DIR='$DATA' \
        I3D_DIR='$DATA/$FEATURES' \
        WANDB_PROJECT=how2sign-slt-agcn \
        WANDB_NAME='$RUN_NAME' \
        python -m fairseq_cli.hydra_train \
            --config-dir '$CONFIG_DIR' \
            --config-name '$CONFIG'
    " >> "$OUTPUT_FILE" 2>&1

echo "========================================" >> "$OUTPUT_FILE"
echo "End Time: $(date)" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"
