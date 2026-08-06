#!/bin/sh
# Submit all 9 mean-of-Conformer feature jobs. Run from the REPO ROOT:
#   bash slurm_jobs/submit_meanconf.sh
# (Do NOT cd into slurm_jobs first — the jobs use $PWD for REPO/slurm_logs.)
for f in slurm_jobs/slurm_meanconf_*.sh; do
    echo "sbatch $f"
    sbatch "$f"
done
