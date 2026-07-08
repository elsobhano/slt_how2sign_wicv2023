#!/bin/sh

#SBATCH --job-name="slt_enc4_dec4"
#SBATCH --partition=cogvis-project,3090
#SBATCH --exclude=aisurrey36
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --time=0-03:00:00
#SBATCH -o slurm_logs/slurm.%N.%j.out

# --- swept hyperparameters for this run ---
ENC_LAYERS=4
DEC_LAYERS=4
LR=1e-3
DP=0.3
MAX_UPDATE=100000

# --- fixed settings ---
CONFIG=agcn_signrep_6_3.yaml
FEATURES=agcn_features
WANDB_PROJECT=how2sign-slt-agcn
WANDB_NAME=agcn_enc${ENC_LAYERS}_dec${DEC_LAYERS}

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

apptainer exec "$IMAGE" bash -lc "
    python setup.py build_ext --inplace || exit 1
    PYTHONPATH='$REPO' SAVE_DIR='$DATA' I3D_DIR='$DATA/$FEATURES' \
    WANDB_PROJECT='$WANDB_PROJECT' WANDB_NAME='$WANDB_NAME' \
    python -m fairseq_cli.hydra_train \
        --config-dir '$CONFIG_DIR' --config-name '$CONFIG' \
        optimization.lr=[$LR] optimization.max_update=$MAX_UPDATE \
        model.dropout=$DP model.attention_dropout=$DP model.activation_dropout=$DP \
        model.encoder_layers=$ENC_LAYERS model.decoder_layers=$DEC_LAYERS
"
