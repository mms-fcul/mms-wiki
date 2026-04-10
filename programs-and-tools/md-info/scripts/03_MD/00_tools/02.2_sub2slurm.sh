#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 02.2_sub2slurm.sh
#
# Generates and submits the Slurm job for 02_runMD.sh.
#
# Design:
#   - source 02.1_MD.conf if present
#   - require only the variables needed to submit the Slurm job
#   - provide sane defaults for optional runtime variables
#   - let 02_runMD.sh validate the truly run-critical variables at execution time
#   - request an early warning signal from Slurm
#   - forward that signal to 02_runMD.sh
#   - resubmit on exit code 10
#   - write a persistent wrapper log in the run directory
# -----------------------------------------------------------------------------

RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOOLS_DIR="${RUN_DIR}/00_tools"
CONF_FILE="${TOOLS_DIR}/02.1_MD.conf"

if [[ ! -f "$CONF_FILE" ]]; then
  echo "ERROR: configuration file not found: $CONF_FILE" >&2
  exit 1
fi

cd "$RUN_DIR"

# shellcheck disable=SC1090
source "$CONF_FILE"

# ----------------------------
# Only require Slurm-submission essentials here
# ----------------------------
: "${JOB_NAME:?Missing JOB_NAME in $CONF_FILE}"
: "${ACCOUNT:?Missing ACCOUNT in $CONF_FILE}"
: "${PARTITION:?Missing PARTITION in $CONF_FILE}"
: "${CPUS:?Missing CPUS in $CONF_FILE}"
: "${MEMORY:?Missing MEMORY in $CONF_FILE}"
: "${WALLTIME:?Missing WALLTIME in $CONF_FILE}"
: "${HEADNODE:?Missing HEADNODE in $CONF_FILE}"

# ----------------------------
# Optional runtime defaults
# ----------------------------
: "${MAXH:=7.0}"
: "${CPT_MIN:=15}"
: "${MAX_RESUB:=100}"
: "${SIGNAL_SECONDS:=900}"
: "${RESUBMIT_MODE:=RESUBMIT}"

: "${BLOCK_NS:=10}"
: "${DT_PS:=0.002}"
: "${TOTAL_NS:=}"

: "${MAXWARN:=1000}"
: "${USE_POSRES_REF:=0}"
: "${GMX_MODE:=CPU}"

: "${USE_SCRATCH:=AUTO}"
: "${KEEP_SCRATCH:=0}"

: "${COMPRESS_DONE_BLOCKS:=1}"
: "${COMPRESS_LOG:=1}"
: "${COMPRESS_TPR:=1}"
: "${COMPRESS_XTC:=0}"
: "${COMPRESS_GRO:=0}"
: "${COMPRESS_EDR:=0}"
: "${COMPRESS_MDP:=0}"
: "${COMPRESS_LEVEL:=1}"

: "${SYS_NAME:=system-name}"
: "${START_CONF:=/initial/init6.gro}"
: "${MDP_TEMPLATE:=01_production.mdp}"
: "${TOP_FILE:=/boxmin/system-name.top}"
: "${INDEX_FILE:=/boxmin/index.ndx}"

# These may be absent at submission time; 02_runMD.sh will validate them later.
: "${CONTAINER_IMAGE:=}"
: "${BOXMIN_DIR_HOST:=}"
: "${INITIAL_DIR_HOST:=}"
: "${FF_DIR_HOST:=}"
: "${RUNTIME:=apptainer}"

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

WRAPPER_LOG="wrapper_\${SLURM_JOB_ID}.log"
exec > >(tee -a "\$WRAPPER_LOG") 2>&1

echo "=== Job start ==="
pwd
hostname
date

cd ${RUN_DIR}

# shellcheck disable=SC1090
source "${CONF_FILE}"

# Re-apply defaults inside the job too
: "\${MAXH:=${MAXH}}"
: "\${CPT_MIN:=${CPT_MIN}}"
: "\${MAX_RESUB:=${MAX_RESUB}}"
: "\${SIGNAL_SECONDS:=${SIGNAL_SECONDS}}"
: "\${RESUBMIT_MODE:=${RESUBMIT_MODE}}"

: "\${BLOCK_NS:=${BLOCK_NS}}"
: "\${DT_PS:=${DT_PS}}"
: "\${TOTAL_NS:=${TOTAL_NS}}"

: "\${MAXWARN:=${MAXWARN}}"
: "\${USE_POSRES_REF:=${USE_POSRES_REF}}"
: "\${GMX_MODE:=${GMX_MODE}}"

: "\${USE_SCRATCH:=${USE_SCRATCH}}"
: "\${KEEP_SCRATCH:=${KEEP_SCRATCH}}"

: "\${COMPRESS_DONE_BLOCKS:=${COMPRESS_DONE_BLOCKS}}"
: "\${COMPRESS_LOG:=${COMPRESS_LOG}}"
: "\${COMPRESS_TPR:=${COMPRESS_TPR}}"
: "\${COMPRESS_XTC:=${COMPRESS_XTC}}"
: "\${COMPRESS_GRO:=${COMPRESS_GRO}}"
: "\${COMPRESS_EDR:=${COMPRESS_EDR}}"
: "\${COMPRESS_MDP:=${COMPRESS_MDP}}"
: "\${COMPRESS_LEVEL:=${COMPRESS_LEVEL}}"

: "\${SYS_NAME:=${SYS_NAME}}"
: "\${START_CONF:=${START_CONF}}"
: "\${MDP_TEMPLATE:=${MDP_TEMPLATE}}"
: "\${TOP_FILE:=${TOP_FILE}}"
: "\${INDEX_FILE:=${INDEX_FILE}}"

: "\${CONTAINER_IMAGE:=${CONTAINER_IMAGE}}"
: "\${BOXMIN_DIR_HOST:=${BOXMIN_DIR_HOST}}"
: "\${INITIAL_DIR_HOST:=${INITIAL_DIR_HOST}}"
: "\${FF_DIR_HOST:=${FF_DIR_HOST}}"
: "\${RUNTIME:=${RUNTIME}}"

export MAXH CPT_MIN MAX_RESUB SIGNAL_SECONDS RESUBMIT_MODE
export TOTAL_NS BLOCK_NS DT_PS
export MAXWARN USE_POSRES_REF GMX_MODE
export USE_SCRATCH KEEP_SCRATCH
export COMPRESS_DONE_BLOCKS COMPRESS_LOG COMPRESS_TPR COMPRESS_XTC
export COMPRESS_GRO COMPRESS_EDR COMPRESS_MDP COMPRESS_LEVEL
export SYS_NAME START_CONF MDP_TEMPLATE TOP_FILE INDEX_FILE
export CONTAINER_IMAGE BOXMIN_DIR_HOST INITIAL_DIR_HOST FF_DIR_HOST RUNTIME

echo "Detected total simulation length from MDP: TOTAL_NS=\${TOTAL_NS} ns"
echo "Block size: BLOCK_NS=\${BLOCK_NS} ns"
echo "Scratch mode: USE_SCRATCH=\${USE_SCRATCH} KEEP_SCRATCH=\${KEEP_SCRATCH}"
echo "Early warning signal: USR1 \${SIGNAL_SECONDS} s before walltime"
echo "Resubmission mode: \${RESUBMIT_MODE}"
echo "Wrapper log: \$WRAPPER_LOG"

COUNTER_FILE=".resub_count_md"
count=0
if [[ -f "\$COUNTER_FILE" ]]; then
  count=\$(cat "\$COUNTER_FILE" 2>/dev/null || echo 0)
fi

echo "Resubmission count so far: \$count (cap=\$MAX_RESUB)"
if (( count >= MAX_RESUB )); then
  echo "ERROR: reached resubmission cap (\$MAX_RESUB). Not resubmitting further." >&2
  exit 9
fi

echo "Checking container runtime..."
which singularity || true
which apptainer || true
singularity --version || true
apptainer --version || true

term_requested=0
child_pid=""

forward_stop() {
  echo "[\$(date)] Batch shell received stop signal."
  term_requested=1
  if [[ -n "\${child_pid}" ]] && kill -0 "\${child_pid}" 2>/dev/null; then
    echo "[\$(date)] Forwarding TERM to 02_runMD.sh (pid=\${child_pid})"
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

echo "02_runMD.sh exit code: \$rc"
date

if [[ "\$rc" -eq 0 ]]; then
  echo "Production completed. Done."
  rm -f "\$COUNTER_FILE"
  exit 0
elif [[ "\$rc" -eq 10 ]]; then
  count=\$((count + 1))
  echo "\$count" > "\$COUNTER_FILE"

  echo "Stopped cleanly with checkpoint available."
  echo "Updated resubmission count: \$count"

  if [[ "\$RESUBMIT_MODE" == "REQUEUE" ]]; then
    if scontrol requeue "\$SLURM_JOB_ID" 2>/dev/null; then
      echo "Requeued current job successfully."
      exit 0
    else
      echo "Requeue failed; falling back to sbatch resubmission."
    fi
  fi

  new_job=\$(sbatch "\$0")
  echo "Resubmitted as: \$new_job"
  exit 0
else
  if [[ "\$term_requested" -eq 1 ]]; then
    echo "ERROR: batch shell received termination warning, but child did not exit cleanly with rc=10." >&2
  fi
  echo "ERROR: production failed (exit code \$rc). Not resubmitting." >&2
  exit "\$rc"
fi
EOF

chmod +x "$SLURM_FILE"

if [[ "${HEADNODE}" == "local" ]]; then
  sbatch "$SLURM_FILE"
else
  ssh -tt "$HEADNODE" "cd '$(printf %q "$RUN_DIR")' && sbatch '$(printf %q "$SLURM_FILE")'"
fi
