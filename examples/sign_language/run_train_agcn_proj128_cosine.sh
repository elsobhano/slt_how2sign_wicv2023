#!/usr/bin/env bash
# Separate experiment: 128-d AGCN SSL-projection-head features with SINGLE cosine
# annealing (one cosine decay over the whole run, no warm restarts). Runs from
# scratch in its own save dir.
set -e

REPO=~/Documents/Code/slt_how2sign_wicv2023
DATA=$REPO/data/how2sign
CFG=$REPO/examples/sign_language/config/wicv_cvpr23/i3d_best
SLT=~/miniconda3/envs/slt-how2sign/bin

export WANDB_API_KEY=1af8cc2a4ed95f2ba66c31d193caf3dd61c3a41f

cd $REPO
SAVE_DIR=$DATA \
I3D_DIR=$DATA/agcn_features_proj128 \
WANDB_PROJECT=how2sign-slt-agcn \
WANDB_NAME=agcn_proj128_6_3_cosine \
CUDA_VISIBLE_DEVICES=0 \
PYTHONPATH=$REPO \
$SLT/fairseq-hydra-train \
  --config-dir $CFG \
  --config-name agcn_signrep_6_3_proj128_cosine.yaml
