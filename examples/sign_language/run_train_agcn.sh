#!/usr/bin/env bash
# Train the Tarrés baseline_6_3 Transformer on our 256-d AGCN SignRep features.
# Replicates SignRep Tab.8: same translation framework, our features instead of I3D.
set -e

REPO=~/Documents/Code/slt_how2sign_wicv2023
DATA=$REPO/data/how2sign
CFG=$REPO/examples/sign_language/config/wicv_cvpr23/i3d_best
SLT=~/miniconda3/envs/slt-how2sign/bin

# wandb (key from SSignRep/configs/wandb.py). Use WANDB_MODE=offline to disable.
export WANDB_API_KEY=1af8cc2a4ed95f2ba66c31d193caf3dd61c3a41f

cd $REPO
SAVE_DIR=$DATA \
I3D_DIR=$DATA/agcn_features \
WANDB_PROJECT=how2sign-slt-agcn \
WANDB_NAME=agcn_signrep_6_3 \
CUDA_VISIBLE_DEVICES=0 \
PYTHONPATH=$REPO \
$SLT/fairseq-hydra-train \
  --config-dir $CFG \
  --config-name agcn_signrep_6_3.yaml
