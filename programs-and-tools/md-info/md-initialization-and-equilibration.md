---
layout: page
title: MD - Initialization and Equilibration
pinned: false
permalink: /programs-and-tools/md-info/md-initialization-and-equilibration/
---

This page describes the initialization stage of the molecular dynamics workflow.

## Purpose

Initialization is used to relax the minimized system in a controlled way before production.

For challenging membrane systems, this may require several staged equilibration steps with restraints and carefully chosen coupling schemes.

For many simpler systems, a much shorter protocol is often enough, such as:

- one 1 fs position-restrained equilibration step
- followed by one 2 fs position-restrained equilibration step

## Files used in this stage

- [`00_sub2slurm.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/00_sub2slurm.sh)
- [`01_init.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/01_init.sh)
- [`init1.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/init1.mdp)
- [`init2.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/init2.mdp)
- [`init3.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/init3.mdp)
- [`init4.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/init4.mdp)
- [`init5.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/init5.mdp)
- [`init6.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/init6.mdp)

## Script files

The files used in this stage are available here:

- [`scripts/02_initial/`](/mms-wiki/programs-and-tools/md-info/scripts/02_initial/)

Main files:

- [`00_sub2slurm.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/00_sub2slurm.sh)
- [`01_init.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/01_init.sh)
- [`init1.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/init1.mdp) to [`init6.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/init6.mdp)

## General workflow

The initialization stage is designed to be robust under walltime-limited jobs.

The workflow supports:

- stage-by-stage execution
- checkpoint creation for each stage
- restart from checkpoints
- skipping already completed stages
- clean stopping with `-maxh`
- automatic resubmission through Slurm when a run stops cleanly

## [`01_init.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/01_init.sh)

This is the main initialization driver.

Its logic is:

1. determine which stage should run next
2. skip stages already completed
3. run `grompp` only when needed
4. run `mdrun` with checkpointing
5. if a checkpointed clean stop happens due to walltime, exit with code `10`
6. allow the [`00_sub2slurm.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/00_sub2slurm.sh) Slurm wrapper to resubmit the job

When sharing or reusing this script, make sure the stage loop includes the full intended list of initialization stages and does not contain any temporary test-only restriction.

## [`00_sub2slurm.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/00_sub2slurm.sh)

This is the Slurm submission wrapper for the initialization stage.

Its role is to:

- generate the Slurm submission script
- launch [`01_init.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/02_initial/01_init.sh)
- interpret the exit code
- automatically resubmit when the run stopped cleanly due to walltime

The script header and comments should match the actual behavior of the script and should not contain outdated references to old testing modes or replicate logic unless those are truly implemented.

## Practical advice

For difficult systems, initialization may need substantial tuning.

Users should check:

- pressure coupling choices
- restraint strengths
- time step
- membrane stability
- whether the minimized structure is sufficiently relaxed before advancing

In the original ASIC membrane case, this stage was deliberately more elaborate than what would usually be needed for a simpler soluble protein system.

## Output of this stage

At the end of initialization, the system should be stable enough to begin the [production workflow](/mms-wiki/programs-and-tools/md-info/md-production-workflow/) from the final initialization structure.