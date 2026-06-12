#!/bin/sh

#SBATCH --job-name="sltsweep"
#SBATCH --partition=cogvis-project,3090
#SBATCH --exclude=aisurrey36
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --time=1-00:00:00
#SBATCH -o slurm_logs/slurm.%N.%j.out

# One job = one learning rate, running BOTH dropout values sequentially.
# Submit 3 of these (one LR each) via submit_sweep.sh -> 3 jobs x 2 runs = 6 configs.

# --- swept hyperparameters (LR comes from the submitter; dropouts run in-job) ---
LR=${LR:-1e-3}
DROPOUTS=${DROPOUTS:-"0.1 0.3"}
MAX_UPDATE=${MAX_UPDATE:-50000}     # sweep cap; run the winner to 200k afterwards

# --- fixed experiment settings ---
CONFIG=${CONFIG:-agcn_signrep_6_3.yaml}
FEATURES=${FEATURES:-agcn_features}
WANDB_PROJECT=how2sign-slt-agcn

# --- paths ---
IMAGE=docker://container-registry.surrey.ac.uk/shared-containers/slt-how-2-sign
REPO="$PWD"
if   [ -d /projects/u6ei ];      then DATA=/projects/u6ei/sa04359/how2sign_wicv
elif [ -d /mnt/fast/nobackup ];  then DATA=/mnt/fast/nobackup/scratch4weeks/sa04359/how2sign_wicv
else                                  DATA=$REPO/data/how2sign
fi
CONFIG_DIR=examples/sign_language/config/wicv_cvpr23/i3d_best
export WANDB_API_KEY=1af8cc2a4ed95f2ba66c31d193caf3dd61c3a41f

mkdir -p slurm_logs outputs

apptainer exec "$IMAGE" bash -lc "
    python setup.py build_ext --inplace || exit 1
    for DP in $DROPOUTS; do
        NAME=agcn_${FEATURES}_lr${LR}_dp\${DP}
        echo '==================== '\$NAME' ===================='
        PYTHONPATH='$REPO' \
        SAVE_DIR='$DATA' \
        I3D_DIR='$DATA/$FEATURES' \
        WANDB_PROJECT='$WANDB_PROJECT' \
        WANDB_NAME=\$NAME \
        python -m fairseq_cli.hydra_train \
            --config-dir '$CONFIG_DIR' \
            --config-name '$CONFIG' \
            optimization.lr=[$LR] \
            optimization.max_update=$MAX_UPDATE \
            model.dropout=\${DP} \
            model.attention_dropout=\${DP} \
            model.activation_dropout=\${DP}
    done
"
