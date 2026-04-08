#!/bin/bash
set -euo pipefail

RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOOLS_DIR="${RUN_DIR}/00_tools"
CONF_FILE="${TOOLS_DIR}/02.1_MD.conf"

[[ -f "$CONF_FILE" ]] || { echo "ERROR: configuration file not found: $CONF_FILE" >&2; exit 1; }

cd "$RUN_DIR"
source "$CONF_FILE"

SLURM_FILE="${JOB_NAME}.slurm"

cat <<EOF > "$SLURM_FILE"
#!/bin/bash
#SBATCH --job-name=${JOB_NAME}
#SBATCH --account=${ACCOUNT}
#SBATCH --partition=${PARTITION}
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=${CPUS}
#SBATCH --mem=${MEMORY}
#SBATCH --time=${WALLTIME}
#SBATCH --signal=B:USR1@${SIGNAL_SECONDS}
#SBATCH --output=serial_test_%j.log
#SBATCH --open-mode=append

set -euo pipefail

cd ${RUN_DIR}
source "${CONF_FILE}"

COUNTER_FILE=".resub_count_md"
count=0
if [[ -f "\$COUNTER_FILE" ]]; then
  count=\$(cat "\$COUNTER_FILE" 2>/dev/null || echo 0)
fi

if (( count >= MAX_RESUB )); then
  echo "ERROR: reached resubmission cap (\$MAX_RESUB). Not resubmitting further." >&2
  exit 9
fi

term_requested=0
child_pid=""

forward_stop() {
  term_requested=1
  if [[ -n "\${child_pid}" ]] && kill -0 "\${child_pid}" 2>/dev/null; then
    kill -TERM "\${child_pid}" 2>/dev/null || true
  fi
}

trap forward_stop USR1 TERM INT

set +e
./02_runMD.sh &
child_pid=\$!
wait "\$child_pid"
rc=\$?
set -e

if [[ "\$rc" -eq 0 ]]; then
  rm -f "\$COUNTER_FILE"
  exit 0
elif [[ "\$rc" -eq 10 ]]; then
  count=\$((count + 1))
  echo "\$count" > "\$COUNTER_FILE"

  if [[ "\$RESUBMIT_MODE" == "REQUEUE" ]]; then
    if scontrol requeue "\$SLURM_JOB_ID" 2>/dev/null; then
      exit 0
    fi
  fi

  sbatch "\$0"
  exit 0
else
  if [[ "\$term_requested" -eq 1 ]]; then
    echo "ERROR: batch shell received termination warning, but child did not exit cleanly with rc=10." >&2
  fi
  exit "\$rc"
fi
EOF

chmod +x "$SLURM_FILE"

if [[ "${HEADNODE}" == "local" ]]; then
  sbatch "$SLURM_FILE"
else
  ssh -tt "$HEADNODE" "cd '$(printf %q "$RUN_DIR")' && sbatch '$(printf %q "$SLURM_FILE")'"
fi
