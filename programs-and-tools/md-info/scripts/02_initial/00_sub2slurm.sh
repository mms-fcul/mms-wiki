#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 00_sub2slurm.sh
#
# Generate and submit the Slurm job wrapper for the initialization stage.
# The generated Slurm script:
#   - runs ./01_init.sh
#   - if it exits 10 (clean stop due to -maxh), resubmits itself
#   - caps resubmissions to avoid infinite loops
# -----------------------------------------------------------------------------

RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WORK_DIR="$RUN_DIR"

: "${JOB_NAME:=system-init}"
: "${ACCOUNT:=your_account}"
: "${PARTITION:=your_partition}"
: "${CPUS:=8}"
: "${MEMORY:=4G}"
: "${WALLTIME:=08:00:00}"
: "${HEADNODE:=your_login_node}"

: "${MAXH:=7.8}"
: "${CPT_MIN:=15}"
: "${MAX_RESUB:=20}"

SLURM_FILE="${JOB_NAME}.slurm"

cat <<EOF > "${WORK_DIR}/${SLURM_FILE}"
#!/bin/bash
#SBATCH --job-name=${JOB_NAME}
#SBATCH --account=${ACCOUNT}
#SBATCH --partition=${PARTITION}
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=${CPUS}
#SBATCH --mem=${MEMORY}
#SBATCH --time=${WALLTIME}
#SBATCH --output=serial_test_%j.log

set -euo pipefail

echo "=== Job start ==="
pwd
hostname
date

cd ${WORK_DIR}

export MAXH="\${MAXH:-${MAXH}}"
export CPT_MIN="\${CPT_MIN:-${CPT_MIN}}"
export MAX_RESUB="\${MAX_RESUB:-${MAX_RESUB}}"

COUNTER_FILE=".resub_count_init"
count=0
if [[ -f "\$COUNTER_FILE" ]]; then
  count=\$(cat "\$COUNTER_FILE" 2>/dev/null || echo 0)
fi

echo "Resubmission count so far: \$count (cap=\$MAX_RESUB)"
if (( count >= MAX_RESUB )); then
  echo "ERROR: reached resubmission cap (\$MAX_RESUB). Not resubmitting further." >&2
  exit 9
fi

set +e
./01_init.sh
rc=\$?
set -e

echo "01_init.sh exit code: \$rc"
date

if [[ "\$rc" -eq 0 ]]; then
  echo "Initialization completed. Done."
  rm -f "\$COUNTER_FILE"
  exit 0
elif [[ "\$rc" -eq 10 ]]; then
  count=\$((count + 1))
  echo "\$count" > "\$COUNTER_FILE"
  echo "Stopped due to -maxh; resubmitting \$0 (count=\$count)..."
  sbatch "\$0"
  exit 0
else
  echo "ERROR: initialization failed (exit code \$rc). Not resubmitting." >&2
  exit "\$rc"
fi
EOF

chmod +x "${WORK_DIR}/${SLURM_FILE}"

if [[ "${HEADNODE}" == "local" ]]; then
  cd "${WORK_DIR}"
  sbatch "${SLURM_FILE}"
else
  ssh -tt "${HEADNODE}" "cd '$(printf %q "$WORK_DIR")' && sbatch '$(printf %q "${SLURM_FILE}")'"
fi
