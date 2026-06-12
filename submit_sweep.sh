#!/bin/sh
# Submit the LR x dropout grid as 3 SLURM jobs (one per learning rate);
# each job runs both dropout values (0.1, 0.3) sequentially -> 6 configs total.
# Run from the repo root:  bash submit_sweep.sh

for LR in 5e-4 1e-3 2e-3; do
    LR=$LR DROPOUTS="0.1 0.3" MAX_UPDATE=50000 \
    FEATURES=agcn_features CONFIG=agcn_signrep_6_3.yaml \
    sbatch slurm_slt_sweep.sh
done
