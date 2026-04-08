#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 01_init.sh
#
# Robust multi-stage initialization with:
#   - per-stage checkpoints: state_initX.cpt
#   - restart safety: continues from checkpoint if present
#   - stage skipping if the log indicates completion
#   - clean walltime usage: uses -maxh and exits 10 when resubmission is needed
#
# Exit codes:
#   0  all stages completed
#   10 stopped due to -maxh before finishing a stage (safe to resubmit)
#   >0 failure
# -----------------------------------------------------------------------------

: "${CONTAINER_IMAGE:?Set CONTAINER_IMAGE to your CpHMD / GROMACS .sif image.}"
: "${BOXMIN_DIR_HOST:?Set BOXMIN_DIR_HOST to the host path of your 01_box-min directory.}"
: "${FF_DIR_HOST:?Set FF_DIR_HOST to the host directory containing your force field.}"

: "${RUNTIME:=singularity}"
: "${GMX_MODE:=GPU}"
: "${CONTAINER_WORKDIR:=/initial}"
: "${BOXMIN_CONT:=/boxmin}"
: "${SYS_NAME:=ASIC1a-Membrane}"
: "${START_CONF:=${BOXMIN_CONT}/min2.gro}"
: "${TOP_FILE:=${BOXMIN_CONT}/${SYS_NAME}.top}"
: "${INDEX_FILE:=${BOXMIN_CONT}/index.ndx}"
: "${INIT_STAGES:=1 2 3 4 5 6}"
: "${CPUS:=${SLURM_CPUS_PER_TASK:-8}}"
: "${MAXH:=7.8}"
: "${CPT_MIN:=15}"

WORK_DIR="$(pwd -P)"
Dir_host="$WORK_DIR"
Dir_cont="${CONTAINER_WORKDIR}"

[[ -f "$CONTAINER_IMAGE" ]] || { echo "ERROR: container image not found: $CONTAINER_IMAGE" >&2; exit 1; }

if [[ "${GMX_MODE}" == "GPU" ]]; then
  gmx=("$RUNTIME" exec
        --nv
        --bind "${Dir_host}:${Dir_cont}"
        --bind "${BOXMIN_DIR_HOST}:${BOXMIN_CONT}"
        --bind "${FF_DIR_HOST}:/ff"
        --pwd "${Dir_cont}"
        "${CONTAINER_IMAGE}"
        /gromacs-gpu/bin/gmx)
else
  gmx=("$RUNTIME" exec
        --bind "${Dir_host}:${Dir_cont}"
        --bind "${BOXMIN_DIR_HOST}:${BOXMIN_CONT}"
        --bind "${FF_DIR_HOST}:/ff"
        --pwd "${Dir_cont}"
        "${CONTAINER_IMAGE}"
        /gromacs/bin/gmx)
fi

GPU_SUPPORT="$("${gmx[@]}" --version 2>/dev/null | awk -F: '/GPU support/ {gsub(/^[ \t]+/, "", $2); print $2}')"
GPU_ID="${SLURM_LOCALID:-0}"

if [[ "${GMX_MODE}" == "CPU" ]]; then
  echo "GMX_MODE=CPU -> forcing CPU execution"
  OFFLOAD_FLAGS=(-nb cpu -pme cpu -bonded cpu -update cpu)
elif [[ -n "$GPU_SUPPORT" && "$GPU_SUPPORT" != "disabled" ]]; then
  echo "GROMACS GPU support: $GPU_SUPPORT -> enabling GPU offload"
  OFFLOAD_FLAGS=(-nb gpu -pme auto -bonded auto -update auto -gpu_id "$GPU_ID")
else
  echo "GPU support unavailable or disabled -> running CPU-only"
  OFFLOAD_FLAGS=(-nb cpu -pme cpu -bonded cpu -update cpu)
fi

log_has_finished() {
  local base="$1"
  local log="${base}.log"
  local gz="${base}.log.gz"
  local tgz="${base}.log.tgz"

  if [[ -f "$log" ]]; then
    grep -q "Finished mdrun" "$log"
  elif [[ -f "$gz" ]]; then
    zgrep -q "Finished mdrun" "$gz"
  elif [[ -f "$tgz" ]]; then
    local member
    member="$(tar -tzf "$tgz" | awk '/\.log$/ {print; exit}')"
    [[ -n "$member" ]] || return 1
    tar -xOzf "$tgz" "$member" | grep -q "Finished mdrun"
  else
    return 1
  fi
}

log_has_maxh_stop() {
  local base="$1"
  local log="${base}.log"
  local gz="${base}.log.gz"
  local tgz="${base}.log.tgz"
  local pat='maxh|Maximum allowed wallclock|will stop|stopping.*wall|Reached the maximum allowed runtime'

  if [[ -f "$log" ]]; then
    grep -Ei -q "$pat" "$log"
  elif [[ -f "$gz" ]]; then
    zgrep -Ei -q "$pat" "$gz"
  elif [[ -f "$tgz" ]]; then
    local member
    member="$(tar -tzf "$tgz" | awk '/\.log$/ {print; exit}')"
    [[ -n "$member" ]] || return 1
    tar -xOzf "$tgz" "$member" | grep -Ei -q "$pat"
  else
    return 1
  fi
}

need_checkpoint_or_abort() {
  local base="$1"
  local cpt="$2"

  if [[ ! -f "$cpt" ]] && ( [[ -f "${base}.log" ]] || [[ -f "${base}.log.gz" ]] || [[ -f "${base}.log.tgz" ]] ); then
    if log_has_finished "$base"; then
      return 0
    fi
    echo "ERROR: Found log for ${base} but checkpoint ${cpt} is missing. Refusing to restart to avoid overwriting." >&2
    exit 2
  fi
}

echo "Run dir (host): ${Dir_host}"
echo "Run dir (cont): ${Dir_cont}"
echo "Node: $(hostname)"
echo "Date: $(date)"
"${gmx[@]}" --version | sed -n '1,30p' || true

prev="$START_CONF"

for curr in ${INIT_STAGES}; do
  base="init${curr}"
  tpr="${base}.tpr"
  mdp="${base}.mdp"
  outgro="${base}.gro"
  cpt="state_init${curr}.cpt"

  if log_has_finished "$base"; then
    echo "Stage ${curr}: already finished. Skipping."
    prev="$outgro"
    continue
  fi

  need_checkpoint_or_abort "$base" "$cpt"

  if [[ ! -f "$tpr" ]]; then
    echo "Stage ${curr}: running grompp -> ${tpr}"
    "${gmx[@]}" grompp \
      -f "$mdp" \
      -po "${base}_out.mdp" \
      -c "$prev" -r "$prev" \
      -n "$INDEX_FILE" -p "$TOP_FILE" \
      -pp "TMP_processed_${base}.top" \
      -o "$tpr" \
      -maxwarn 1000
  else
    echo "Stage ${curr}: ${tpr} exists, skipping grompp."
  fi

  mdrun_common=(
    -ntmpi 1
    -ntomp "$CPUS"
    -pin on
    "${OFFLOAD_FLAGS[@]}"
    -cpt "$CPT_MIN"
    -maxh "$MAXH"
    -cpo "$cpt"
    -nice 19
    -s "$tpr"
    -x "${base}.xtc"
    -c "$outgro"
    -e "${base}.edr"
    -g "${base}.log"
  )

  echo "Stage ${curr}: running mdrun (MAXH=${MAXH}h, cpt=${CPT_MIN}min, cptfile=${cpt})"

  if [[ -f "$cpt" ]]; then
    echo "Stage ${curr}: checkpoint found (${cpt}), continuing with -cpi and -append."
    "${gmx[@]}" mdrun "${mdrun_common[@]}" -cpi "$cpt" -append || {
      echo "ERROR: mdrun failed for stage ${curr}." >&2
      exit 3
    }
  else
    echo "Stage ${curr}: no checkpoint, starting fresh."
    "${gmx[@]}" mdrun "${mdrun_common[@]}" || {
      echo "ERROR: mdrun failed for stage ${curr}." >&2
      exit 3
    }
  fi

  if log_has_finished "$base"; then
    echo "Stage ${curr}: completed."
    prev="$outgro"
    continue
  fi

  if [[ -f "$cpt" ]] && log_has_maxh_stop "$base"; then
    echo "Stage ${curr}: stopped due to walltime (-maxh). Checkpoint present -> safe to resubmit."
    exit 10
  fi

  echo "ERROR: Stage ${curr} not finished, and it does not look like a clean -maxh stop." >&2
  echo "       Please inspect ${base}.log / ${base}.log.gz / ${base}.log.tgz." >&2
  exit 4
done

rm -f *~ *# .*~ .*# TMP_processed_init*.top

echo "All initialization stages finished successfully."
exit 0
