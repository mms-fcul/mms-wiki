#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONF_FILE="${SCRIPT_DIR}/00_tools/02.1_MD.conf"
if [[ -f "$CONF_FILE" ]]; then
  source "$CONF_FILE"
fi

PERSIST_DIR="$SCRIPT_DIR"
PERSIST_CONT="/persist"

USE_SCRATCH="${USE_SCRATCH:-AUTO}"
KEEP_SCRATCH="${KEEP_SCRATCH:-0}"

SCRATCH_ACTIVE=0
WORK_DIR="$PERSIST_DIR"

STOP_REQUESTED=0
MDRUN_PID=""

COMPRESS_DONE_BLOCKS="${COMPRESS_DONE_BLOCKS:-1}"
COMPRESS_LOG="${COMPRESS_LOG:-1}"
COMPRESS_TPR="${COMPRESS_TPR:-1}"
COMPRESS_XTC="${COMPRESS_XTC:-0}"
COMPRESS_GRO="${COMPRESS_GRO:-0}"
COMPRESS_EDR="${COMPRESS_EDR:-0}"
COMPRESS_MDP="${COMPRESS_MDP:-0}"
COMPRESS_LEVEL="${COMPRESS_LEVEL:-1}"

choose_scratch_base() {
  local cand
  for cand in "${SLURM_TMPDIR:-}" "${TMPDIR:-}" "/tmp"; do
    [[ -n "$cand" ]] || continue
    if [[ -d "$cand" && -w "$cand" ]]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

want_scratch() {
  case "${USE_SCRATCH}" in
    1|yes|YES|true|TRUE|on|ON) return 0 ;;
    0|no|NO|false|FALSE|off|OFF) return 1 ;;
    AUTO|auto|"") choose_scratch_base >/dev/null 2>&1; return $? ;;
    *) echo "ERROR: invalid USE_SCRATCH value: ${USE_SCRATCH}" >&2; exit 8 ;;
  esac
}

stage_in_to_scratch() {
  local scratch_base="$1"
  local rsync_status=0
  local jobtag="${SLURM_JOB_ID:-$$}"

  WORK_DIR="${scratch_base%/}/${USER}_md_${jobtag}_$(basename "$PERSIST_DIR")"
  mkdir -p "$WORK_DIR"

  rsync -a --no-group --no-owner --omit-dir-times \
    --include='00_tools/***' \
    --include='*.mdp' --include='*.mdp.gz' \
    --include='*.gro' --include='*.gro.gz' \
    --include='*.tpr' --include='*.tpr.gz' \
    --include='*.xtc' --include='*.xtc.gz' \
    --include='*.trr' --include='*.trr.gz' \
    --include='*.edr' --include='*.edr.gz' \
    --include='*.log' --include='*.log.gz' --include='*.log.tgz' \
    --include='state_*.cpt' --include='state_*_prev.cpt' \
    --include='*.xvg' --include='*.info' --include='*.dat' \
    --include='*.RUNNING' --include='*.DONE' --include='*.FAILED' \
    --exclude='*' \
    "${PERSIST_DIR}/" "${WORK_DIR}/" || rsync_status=$?

  if [[ "$rsync_status" -ne 0 ]]; then
    echo "ERROR: failed to stage files into scratch." >&2
    exit 11
  fi

  SCRATCH_ACTIVE=1
}

sync_back_from_scratch() {
  local rsync_status=0
  [[ "$SCRATCH_ACTIVE" -eq 1 && -d "$WORK_DIR" ]] || return 0

  rsync -a --no-group --no-owner --omit-dir-times \
    --include='00_tools/***' \
    --include='*.mdp' --include='*.mdp.gz' \
    --include='*.gro' --include='*.gro.gz' \
    --include='*.tpr' --include='*.tpr.gz' \
    --include='*.xtc' --include='*.xtc.gz' \
    --include='*.trr' --include='*.trr.gz' \
    --include='*.edr' --include='*.edr.gz' \
    --include='*.log' --include='*.log.gz' --include='*.log.tgz' \
    --include='*.xvg' --include='*.info' --include='*.dat' \
    --include='*.RUNNING' --include='*.DONE' --include='*.FAILED' \
    --exclude='state_*.cpt' --exclude='state_*_prev.cpt' \
    --exclude='*' \
    "${WORK_DIR}/" "${PERSIST_DIR}/" || rsync_status=$?

  [[ "$rsync_status" -eq 0 ]] || echo "WARNING: rsync back reported a non-zero status." >&2
  return "$rsync_status"
}

mark_block_running() {
  local base="$1"
  rm -f "${PERSIST_DIR}/${base}.DONE" "${PERSIST_DIR}/${base}.FAILED"
  touch "${PERSIST_DIR}/${base}.RUNNING"
  if [[ "$SCRATCH_ACTIVE" -eq 1 ]]; then
    rm -f "${WORK_DIR}/${base}.DONE" "${WORK_DIR}/${base}.FAILED"
    touch "${WORK_DIR}/${base}.RUNNING"
  fi
}

mark_block_done() {
  local base="$1"
  rm -f "${PERSIST_DIR}/${base}.RUNNING" "${PERSIST_DIR}/${base}.FAILED"
  touch "${PERSIST_DIR}/${base}.DONE"
  if [[ "$SCRATCH_ACTIVE" -eq 1 ]]; then
    rm -f "${WORK_DIR}/${base}.RUNNING" "${WORK_DIR}/${base}.FAILED"
    touch "${WORK_DIR}/${base}.DONE"
  fi
}

mark_block_failed() {
  local base="$1"
  rm -f "${PERSIST_DIR}/${base}.RUNNING"
  touch "${PERSIST_DIR}/${base}.FAILED"
  if [[ "$SCRATCH_ACTIVE" -eq 1 ]]; then
    rm -f "${WORK_DIR}/${base}.RUNNING"
    touch "${WORK_DIR}/${base}.FAILED"
  fi
}

get_gzip_cmd() {
  if command -v pigz >/dev/null 2>&1; then
    printf 'pigz -%s -p 1' "$COMPRESS_LEVEL"
  else
    printf 'gzip -%s' "$COMPRESS_LEVEL"
  fi
}

gzip_one_file() {
  local f="$1"
  local gzcmd
  [[ -f "$f" && -s "$f" && ! -f "${f}.gz" ]] || return 0
  gzcmd="$(get_gzip_cmd)"
  # shellcheck disable=SC2086
  $gzcmd -- "$f"
}

compress_block_artifacts_in_dir() {
  local dir="$1" base="$2"
  [[ -d "$dir" ]] || return 0
  [[ "$COMPRESS_LOG" == "1" ]] && gzip_one_file "${dir}/${base}.log"
  [[ "$COMPRESS_TPR" == "1" ]] && gzip_one_file "${dir}/${base}.tpr"
  [[ "$COMPRESS_XTC" == "1" ]] && gzip_one_file "${dir}/${base}.xtc"
  [[ "$COMPRESS_GRO" == "1" ]] && gzip_one_file "${dir}/${base}.gro"
  [[ "$COMPRESS_EDR" == "1" ]] && gzip_one_file "${dir}/${base}.edr"
  if [[ "$COMPRESS_MDP" == "1" ]]; then
    gzip_one_file "${dir}/${base}.mdp"
    gzip_one_file "${dir}/${base}_out.mdp"
  fi
}

compress_completed_block_artifacts() {
  local base="$1"
  [[ "$COMPRESS_DONE_BLOCKS" == "1" ]] || return 0
  [[ "$SCRATCH_ACTIVE" -eq 1 && -d "$WORK_DIR" ]] && compress_block_artifacts_in_dir "$WORK_DIR" "$base"
  compress_block_artifacts_in_dir "$PERSIST_DIR" "$base"
  sync_back_from_scratch || true
}

request_stop() {
  STOP_REQUESTED=1
  if [[ -n "${MDRUN_PID}" ]] && kill -0 "${MDRUN_PID}" 2>/dev/null; then
    kill -TERM "${MDRUN_PID}" 2>/dev/null || true
  fi
}

cleanup() {
  local rc=$?
  trap - EXIT
  sync_back_from_scratch || true
  if [[ "$SCRATCH_ACTIVE" -eq 1 ]]; then
    if [[ "$KEEP_SCRATCH" == "1" || "$rc" -ne 0 ]]; then
      echo "Keeping scratch directory for debugging: $WORK_DIR"
    else
      rm -rf "$WORK_DIR" || true
    fi
  fi
  exit "$rc"
}

trap request_stop TERM USR1 INT
trap cleanup EXIT

if want_scratch; then
  SCRATCH_BASE="$(choose_scratch_base)"
  stage_in_to_scratch "$SCRATCH_BASE"
fi

cd "$WORK_DIR"
Dir_host="$(pwd -P)"
Dir_cont="/prod"

: "${CONTAINER_IMAGE:?Set CONTAINER_IMAGE in 00_tools/02.1_MD.conf}"
: "${BOXMIN_DIR_HOST:?Set BOXMIN_DIR_HOST in 00_tools/02.1_MD.conf}"
: "${INITIAL_DIR_HOST:?Set INITIAL_DIR_HOST in 00_tools/02.1_MD.conf}"
: "${FF_DIR_HOST:?Set FF_DIR_HOST in 00_tools/02.1_MD.conf}"
: "${RUNTIME:=apptainer}"

sys="${SYS_NAME:-system-name}"
top="${TOP_FILE:-/boxmin/${sys}.top}"
index="${INDEX_FILE:-/boxmin/index.ndx}"
start_conf="${START_CONF:-/initial/init6.gro}"
template_mdp="${MDP_TEMPLATE:-01_production.mdp}"

CPUs="${SLURM_CPUS_PER_TASK:-${CPUS:-8}}"
MAXH="${MAXH:-7.0}"
CPT_MIN="${CPT_MIN:-15}"
TOTAL_NS="${TOTAL_NS:-}"
BLOCK_NS="${BLOCK_NS:-10}"
DT_PS="${DT_PS:-0.002}"
USE_POSRES_REF="${USE_POSRES_REF:-0}"
MAXWARN="${MAXWARN:-1000}"
GMX_MODE="${GMX_MODE:-CPU}"

[[ -n "$TOTAL_NS" ]] || { echo "ERROR: TOTAL_NS is not set." >&2; exit 7; }

if [[ "${GMX_MODE}" == "GPU" ]]; then
  gmx=("$RUNTIME" exec --nv
        --bind "${Dir_host}:${Dir_cont}"
        --bind "${PERSIST_DIR}:${PERSIST_CONT}"
        --bind "${BOXMIN_DIR_HOST}:/boxmin"
        --bind "${INITIAL_DIR_HOST}:/initial"
        --bind "${FF_DIR_HOST}:/ff"
        --pwd "${Dir_cont}"
        "${CONTAINER_IMAGE}"
        /gromacs-gpu/bin/gmx)
else
  gmx=("$RUNTIME" exec
        --bind "${Dir_host}:${Dir_cont}"
        --bind "${PERSIST_DIR}:${PERSIST_CONT}"
        --bind "${BOXMIN_DIR_HOST}:/boxmin"
        --bind "${INITIAL_DIR_HOST}:/initial"
        --bind "${FF_DIR_HOST}:/ff"
        --pwd "${Dir_cont}"
        "${CONTAINER_IMAGE}"
        /gromacs/bin/gmx)
fi

GPU_SUPPORT="$("${gmx[@]}" --version 2>/dev/null | awk -F: '/GPU support/ {gsub(/^[ \t]+/, "", $2); print $2}')"
GPU_ID="${SLURM_LOCALID:-0}"

if [[ "${GMX_MODE}" == "CPU" ]]; then
  OFFLOAD_FLAGS=(-nb cpu -pme cpu -bonded cpu -update cpu)
elif [[ -n "$GPU_SUPPORT" && "$GPU_SUPPORT" != "disabled" ]]; then
  OFFLOAD_FLAGS=(-nb gpu -pme auto -bonded auto -update auto -gpu_id "$GPU_ID")
else
  OFFLOAD_FLAGS=(-nb cpu -pme cpu -bonded cpu -update cpu)
fi

calc_nsteps() { awk -v ns="$1" -v dt="$DT_PS" 'BEGIN {printf "%.0f", (ns*1000.0)/dt}'; }
calc_num_blocks() { awk -v total="$TOTAL_NS" -v block="$BLOCK_NS" 'BEGIN{n=int(total/block); if(total>n*block)n++; if(n<1)n=1; print n}'; }
block_name() { printf "%03d" "$1"; }
block_ns() { awk -v i="$1" -v total="$TOTAL_NS" -v block="$BLOCK_NS" 'BEGIN{start=(i-1)*block; rem=total-start; if(rem<=0)print 0; else if(rem<block)print rem; else print block}'; }

NUM_BLOCKS="$(calc_num_blocks)"

get_log_tail() {
  local base="$1" n="${2:-400}" log="${base}.log" gz="${base}.log.gz" tgz="${base}.log.tgz"
  if [[ -f "$log" ]]; then
    tail -n "$n" "$log"
  elif [[ -f "$gz" ]]; then
    zcat "$gz" | tail -n "$n"
  elif [[ -f "$tgz" ]]; then
    local member
    member="$(tar -tzf "$tgz" | awk '/\.log$/ {print; exit}')"
    [[ -n "$member" ]] || return 1
    tar -xOzf "$tgz" "$member" | tail -n "$n"
  else
    return 1
  fi
}

log_latest_has_finished() { get_log_tail "$1" 400 | grep -q "Finished mdrun"; }
log_latest_has_maxh_stop() { get_log_tail "$1" 400 | grep -Ei -q 'Run time exceeded|will terminate the run within|Maximum allowed wallclock|Reached the maximum allowed runtime|stopping.*wall|maxh'; }

stage_is_complete() {
  local base="$1"
  [[ -f "${PERSIST_DIR}/${base}.DONE" ]] && return 0
  log_latest_has_maxh_stop "$base" && return 1
  log_latest_has_finished "$base"
}

checkpoint_looks_valid() { [[ -s "$1" ]]; }

need_checkpoint_or_abort() {
  local base="$1" cpt_host="$2"
  if ! checkpoint_looks_valid "$cpt_host" && ( [[ -f "${base}.log" ]] || [[ -f "${base}.log.gz" ]] || [[ -f "${base}.log.tgz" ]] ); then
    stage_is_complete "$base" && return 0
    echo "ERROR: Found log for ${base} but valid checkpoint ${cpt_host} is missing." >&2
    exit 2
  fi
}

previous_conf_for_block() {
  local idx="$1"
  if (( idx == 1 )); then
    echo "$start_conf"
  else
    echo "${Dir_cont}/$(block_name "$((idx - 1))").gro"
  fi
}

make_block_mdp() {
  local base="$1" this_ns="$2" mdp_out="${Dir_cont}/${base}.mdp" template_host nsteps
  nsteps="$(calc_nsteps "$this_ns")"
  if [[ "$template_mdp" = /* ]]; then
    template_host="$template_mdp"
  else
    template_host="${PERSIST_DIR}/${template_mdp}"
  fi
  [[ -f "$template_host" ]] || { echo "ERROR: production template not found: ${template_host}" >&2; exit 6; }
  cp "$template_host" "${Dir_host}/${base}.mdp"
  if grep -Eq '^[[:space:]]*nsteps[[:space:]]*=' "${Dir_host}/${base}.mdp"; then
    sed -i -E "s|^[[:space:]]*nsteps[[:space:]]*=.*|nsteps                  = ${nsteps}|" "${Dir_host}/${base}.mdp"
  else
    printf "\nnsteps                  = %s\n" "$nsteps" >> "${Dir_host}/${base}.mdp"
  fi
  echo "$mdp_out"
}

for (( i=1; i<=NUM_BLOCKS; i++ )); do
  base="$(block_name "$i")"
  this_ns="$(block_ns "$i")"
  awk -v x="$this_ns" 'BEGIN { exit !(x > 0) }' || continue

  prev="$(previous_conf_for_block "$i")"
  tpr="${Dir_cont}/${base}.tpr"
  mdp="$(make_block_mdp "$base" "$this_ns")"
  outgro="${Dir_cont}/${base}.gro"
  cpt_cont="${PERSIST_CONT}/state_${base}.cpt"
  cpt_host="${PERSIST_DIR}/state_${base}.cpt"

  stage_is_complete "$base" && { echo "Block ${base}: already complete. Skipping."; continue; }
  need_checkpoint_or_abort "$base" "$cpt_host"

  if [[ "$prev" = /* ]]; then
    prev_host_check="${Dir_host}/$(basename "$prev")"
    [[ "$prev" == /initial/* ]] && prev_host_check="${INITIAL_DIR_HOST}/$(basename "$prev")"
  else
    prev_host_check="${Dir_host}/${prev}"
  fi

  [[ -f "$prev_host_check" ]] || { echo "ERROR: starting structure for block ${base} not found: ${prev_host_check}" >&2; mark_block_failed "$base"; exit 5; }

  mark_block_running "$base"

  if [[ ! -f "${Dir_host}/${base}.tpr" && ! -f "${Dir_host}/${base}.tpr.gz" ]]; then
    if [[ "$USE_POSRES_REF" -eq 1 ]]; then
      "${gmx[@]}" grompp -f "$mdp" -po "${base}_out.mdp" -c "$prev" -r "$prev" -n "$index" -p "$top" -pp "TMP_processed_${base}.top" -o "$tpr" -maxwarn "$MAXWARN"
    else
      "${gmx[@]}" grompp -f "$mdp" -po "${base}_out.mdp" -c "$prev" -n "$index" -p "$top" -pp "TMP_processed_${base}.top" -o "$tpr" -maxwarn "$MAXWARN"
    fi
  fi

  mdrun_common=(-ntmpi 1 -ntomp "$CPUs" -pin on "${OFFLOAD_FLAGS[@]}" -cpt "$CPT_MIN" -maxh "$MAXH" -cpo "$cpt_cont" -nice 19 -s "$tpr" -x "${base}.xtc" -c "$outgro" -e "${base}.edr" -g "${base}.log")

  set +e
  if checkpoint_looks_valid "$cpt_host"; then
    "${gmx[@]}" mdrun "${mdrun_common[@]}" -cpi "$cpt_cont" -append &
  else
    "${gmx[@]}" mdrun "${mdrun_common[@]}" &
  fi
  MDRUN_PID=$!
  wait "$MDRUN_PID"
  md_rc=$?
  MDRUN_PID=""
  set -e

  sync_back_from_scratch || true

  if [[ "$STOP_REQUESTED" -eq 1 ]]; then
    checkpoint_looks_valid "$cpt_host" && exit 10
    mark_block_failed "$base"
    exit 12
  fi

  if [[ "$md_rc" -ne 0 ]]; then
    if checkpoint_looks_valid "$cpt_host" && log_latest_has_maxh_stop "$base"; then
      exit 10
    fi
    mark_block_failed "$base"
    exit 3
  fi

  if checkpoint_looks_valid "$cpt_host" && log_latest_has_maxh_stop "$base"; then
    exit 10
  fi

  if stage_is_complete "$base"; then
    mark_block_done "$base"
    sync_back_from_scratch || true
    compress_completed_block_artifacts "$base"
    continue
  fi

  mark_block_failed "$base"
  exit 4
done

rm -f *~ *# .*~ .*# TMP_processed_*.top
exit 0
