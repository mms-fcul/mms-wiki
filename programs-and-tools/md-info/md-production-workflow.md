---
layout: page
title: MD - Production Workflow
pinned: false
permalink: /programs-and-tools/md-info/md-production-workflow/
---

This page describes the production MD workflow used in the group.

## Core idea

Production runs are split into numbered blocks such as:

- `001`
- `002`
- `003`

Each block is typically 10 ns, although the last one may be shorter depending on the total simulation length.

This design makes production runs easier to manage under Slurm walltime limits while preserving continuity through checkpointing.

## Script files

The files used in this stage are available here:

- [`scripts/03_MD/`](/mms-wiki/programs-and-tools/md-info/scripts/03_MD/)

## Main files

- [`01_production.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/01_production.mdp)
- [`02_runMD.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/02_runMD.sh)
- [`00_tools/02.1_MD.conf`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.1_MD.conf)
- [`00_tools/02.2_sub2slurm.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.2_sub2slurm.sh)

## Configuration overview

The main configuration file for the production workflow is [`00_tools/02.1_MD.conf`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.1_MD.conf).

This file controls:

- Slurm submission settings
- restart and walltime policy
- block size
- CPU/GPU execution mode
- scratch usage
- compression policy
- system names and input file paths
- container and host-path bindings

The total simulation length is derived automatically from [`01_production.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/01_production.mdp), while the block size is set through `BLOCK_NS` in [`00_tools/02.1_MD.conf`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.1_MD.conf).

## Main design features

The production workflow includes:

- automatic derivation of total simulation length from [`01_production.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/01_production.mdp)
- block-by-block execution
- checkpoint continuation within a block
- clean restart with `-cpi`
- automatic use of `-append` when previous append-compatible outputs are present
- automatic fallback to `-noappend` when a checkpoint exists but prior outputs needed for appending are missing
- optional execution on node-local scratch
- automatic resubmission after clean walltime stops
- persistent checkpoint storage
- optional compression of completed block files
- `.RUNNING`, `.DONE`, and `.FAILED` status markers
- persistent debug logs and per-block failure notes

## Main workflow files

### [`00_tools/02.1_MD.conf`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.1_MD.conf)

This is the central configuration file.

Users should adapt, at minimum:

- `ACCOUNT`
- `PARTITION`
- `CPUS`
- `MEMORY`
- `WALLTIME`
- `HEADNODE`
- `CONTAINER_IMAGE`
- `BOXMIN_DIR_HOST`
- `INITIAL_DIR_HOST`
- `FF_DIR_HOST`

Other important adjustable settings include:

- `BLOCK_NS`
- `MAXH`
- `CPT_MIN`
- `GMX_MODE`
- `USE_SCRATCH`
- `KEEP_SCRATCH`
- compression settings such as `COMPRESS_LOG`, `COMPRESS_TPR`, and `COMPRESS_XTC`

### [`02_runMD.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/02_runMD.sh)

This is the main production driver.

Its role is to:

- loop over numbered blocks
- prepare per-block `.mdp` and `.tpr` files
- decide whether a block is already complete
- continue from checkpoints when available
- use `-append` when possible
- fall back to `-noappend` when append-compatible outputs are missing
- stage files through scratch when enabled
- sync results back to persistent storage
- write persistent logs and failure notes
- compress selected block outputs once a block is fully complete

### [`00_tools/02.2_sub2slurm.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.2_sub2slurm.sh)

This is the Slurm submission wrapper.

Its role is to:

- source [`00_tools/02.1_MD.conf`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.1_MD.conf)
- generate the Slurm submission script
- submit the production job
- request an early warning signal from Slurm before hard walltime
- forward that signal to [`02_runMD.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/02_runMD.sh)
- resubmit when [`02_runMD.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/02_runMD.sh) exits with code `10`

Only the variables needed to submit the Slurm job are required at submission time. Runtime-specific validation is delegated to [`02_runMD.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/02_runMD.sh).

## Why the workflow is structured this way

The main goal is to make long simulations compatible with fair shared use of a cluster.

Instead of submitting very long uninterrupted jobs, the workflow:

- requests a standard walltime
- stops cleanly before the hard limit using `-maxh`
- saves checkpoints regularly
- automatically resubmits
- resumes from the latest checkpoint

This makes long simulations easier to schedule and reduces wasted work.

## Restart philosophy

A key design choice is that checkpoints should be kept on persistent storage, even when heavy output files are staged through scratch.

This is important because checkpoints are the restart-critical files.

Losing trajectories is inconvenient. Losing checkpoints can mean losing the ability to continue the simulation cleanly.

For this reason, the workflow writes checkpoints to persistent storage and only uses `-append` when the previous outputs required for appending are still available. If those files are missing, the workflow falls back to `-noappend` rather than failing unsafely.

## Scratch usage

The workflow supports optional use of node-local scratch for performance.

The general policy is:

- run heavy I/O on scratch when available
- sync results back to persistent storage
- keep checkpoints on persistent storage rather than scratch only

This reduces the risk of data loss when jobs terminate or nodes are cleaned up.

## Compression of completed block artifacts

The workflow can optionally compress selected block outputs, but only after the corresponding block is fully complete.

This is intended to reduce storage usage without interfering with active restarts.

A sensible default policy is defined in [`00_tools/02.1_MD.conf`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.1_MD.conf):

- compress `.log`
- compress `.tpr`
- keep checkpoint files uncompressed
- keep compression off for `.xtc` by default, since extra gains are usually modest
- avoid compressing a shared live `traj.trr` unless the workflow is changed to use block-specific TRR files

## Logging and debugging

The workflow writes persistent logs to the run directory, including:

- Slurm wrapper logs from [`00_tools/02.2_sub2slurm.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.2_sub2slurm.sh)
- production-driver logs from [`02_runMD.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/02_runMD.sh)
- per-block failure notes when a block fails

This is intended to make debugging easier even when scratch directories are removed automatically.

## What users should adapt

Before adapting the workflow to another system, users should review:

- base directory layout
- Slurm account and partition names
- CPU and memory requests
- container path
- force-field directory
- whether the run is CPU or GPU mode
- block size
- walltime and `-maxh`
- scratch policy
- compression policy

The main user-editable settings are concentrated in [`00_tools/02.1_MD.conf`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.1_MD.conf), while submission behavior is controlled by [`00_tools/02.2_sub2slurm.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.2_sub2slurm.sh), and the main execution logic lives in [`02_runMD.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/02_runMD.sh).

## Best practices

Recommended good practices include:

- keep `-maxh` safely below the Slurm walltime
- checkpoint frequently enough to avoid major loss of work
- inspect logs after failures
- never assume another user has the same filesystem layout
- clearly mark local directories that must be edited by each user
- remove test-only edits before sharing scripts with others

## Summary

The most reusable part of the workflow is the production logic implemented through [`02_runMD.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/02_runMD.sh), [`00_tools/02.1_MD.conf`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.1_MD.conf), and [`00_tools/02.2_sub2slurm.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/03_MD/00_tools/02.2_sub2slurm.sh):

- split long production into blocks
- checkpoint regularly
- stop cleanly before walltime
- resubmit automatically
- continue from checkpoints
- store restart-critical files on persistent storage

This logic is broadly useful even when the preparation and initialization stages differ between projects.