#!/bin/sh
# Regularization sweep on the w16_s2 mean-conformer features. Run from REPO ROOT.
for f in slurm_jobs/slurm_meanconf_w16_s2_dp0.4.sh \
         slurm_jobs/slurm_meanconf_w16_s2_dp0.5.sh \
         slurm_jobs/slurm_meanconf_w16_s2_wd0.2.sh \
         slurm_jobs/slurm_meanconf_w16_s2_ls0.2.sh; do
    echo "sbatch $f"; sbatch "$f"
done
