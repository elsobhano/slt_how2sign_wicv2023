#!/bin/sh
# Submit all 9 mean+max+std (768-d) jobs. Run from REPO ROOT:
#   bash slurm_jobs/submit_mms.sh
for f in slurm_jobs/slurm_mms_*.sh; do echo "sbatch $f"; sbatch "$f"; done
