#!/bin/bash
set -euo pipefail

usage="Usage: $(basename "$0") CPUs"

if [[ $# -ne 1 ]]; then
  echo "$usage" >&2
  exit 1
fi

: "${CONTAINER_IMAGE:?Set CONTAINER_IMAGE to your CpHMD / GROMACS .sif image.}"
: "${FF_DIR_HOST:?Set FF_DIR_HOST to the host directory containing your force field.}"
: "${RUNTIME:=singularity}"
: "${SYS_NAME:=ASIC1a-Membrane}"
: "${CONTAINER_WORKDIR:=/boxmin}"

CPUS="$1"
WORK_DIR="$(pwd -P)"

[[ -f "$CONTAINER_IMAGE" ]] || { echo "ERROR: container image not found: $CONTAINER_IMAGE" >&2; exit 1; }
[[ -f "${WORK_DIR}/${SYS_NAME}.gro" ]] || { echo "ERROR: structure not found: ${WORK_DIR}/${SYS_NAME}.gro" >&2; exit 1; }
[[ -f "${WORK_DIR}/${SYS_NAME}.top" ]] || { echo "ERROR: topology not found: ${WORK_DIR}/${SYS_NAME}.top" >&2; exit 1; }
[[ -f "${WORK_DIR}/index.ndx" ]] || { echo "ERROR: index not found: ${WORK_DIR}/index.ndx" >&2; exit 1; }

grom=("$RUNTIME" exec
      --bind "${WORK_DIR}:${CONTAINER_WORKDIR}"
      --bind "${FF_DIR_HOST}:/ff"
      --pwd "${CONTAINER_WORKDIR}"
      "${CONTAINER_IMAGE}"
      gmx)

top="${CONTAINER_WORKDIR}/${SYS_NAME}.top"
index="${CONTAINER_WORKDIR}/index.ndx"

rm -f min?.tpr
for curr in 1 2; do
  prev="${CONTAINER_WORKDIR}/min$((curr-1)).gro"
  if [[ "$curr" -eq 1 ]]; then
    prev="${CONTAINER_WORKDIR}/${SYS_NAME}.gro"
  fi

  [[ -f "${WORK_DIR}/min${curr}.mdp" ]] || { echo "ERROR: min${curr}.mdp not found in ${WORK_DIR}" >&2; exit 1; }

  "${grom[@]}" grompp \
    -f "min${curr}.mdp" \
    -po "min${curr}_out.mdp" \
    -c "${prev}" -r "${prev}" \
    -n "${index}" -p "${top}" \
    -pp "TMP_processed.top" \
    -o "min${curr}.tpr" \
    -maxwarn 1000 -v

  "${grom[@]}" mdrun \
    -nt "$CPUS" \
    -pin auto \
    -s "min${curr}.tpr" \
    -x "min${curr}.xtc" \
    -c "min${curr}.gro" \
    -e "min${curr}.edr" \
    -g "min${curr}.log" \
    -v
done

rm -f *~ *# .*~ .*# TMP_* *.trr

echo "Minimization finished successfully."
