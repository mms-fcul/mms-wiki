---
layout: page
title: MD - Production Workflow
pinned: false
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

- `01_production.mdp`
- `02_runMD.sh`
- `00_tools/02.1_MD.conf`
- `00_tools/02.2_sub2slurm.sh`

## Main design features

The production workflow includes:

- automatic derivation of total simulation length from the production `.mdp`
- block-by-block execution
- checkpoint continuation within a block
- clean restart with `-cpi ... -append`
- optional execution on node-local scratch
- automatic resubmission after clean walltime stops
- persistent checkpoint storage
- optional compression of completed block files
- `.RUNNING`, `.DONE`, and `.FAILED` status markers

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

A sensible default policy is:

- compress `.log`
- compress `.tpr`
- keep checkpoint files uncompressed
- keep compression off for `.xtc` by default, since extra gains are usually modest
- avoid compressing a shared live `traj.trr` unless the workflow is changed to use block-specific TRR files

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

## Best practices

Recommended good practices include:

- keep `-maxh` safely below the Slurm walltime
- checkpoint frequently enough to avoid major loss of work
- inspect logs after failures
- never assume another user has the same filesystem layout
- clearly mark local directories that must be edited by each user
- remove test-only edits before sharing scripts with others

## Summary

The most reusable part of the workflow is the production logic:

- split long production into blocks
- checkpoint regularly
- stop cleanly before walltime
- resubmit automatically
- continue from checkpoints
- store restart-critical files on persistent storage

This logic is broadly useful even when the preparation and initialization stages differ between projects.