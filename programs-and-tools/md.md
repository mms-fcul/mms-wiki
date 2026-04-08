---
layout: page
title: Molecular Dynamics
pinned: false
permalink: /programs-and-tools/md/
---

This section documents the group workflow for molecular dynamics simulations with GROMACS on HPC systems, using containerized execution through Apptainer/Singularity and Slurm-based scheduling.

The workflow is divided into three main stages:

1. [System preparation and minimization](/mms-wiki/programs-and-tools/md-info/md-system-preparation-and-minimization/)
2. [Initialization and equilibration](/mms-wiki/programs-and-tools/md-info/md-initialization-and-equilibration/)
3. [Production workflow](/mms-wiki/programs-and-tools/md-info/md-production-workflow/)

## Script files

The scripts are organized by stage:

- [01_box-min](/mms-wiki/programs-and-tools/md-info/scripts/01_box-min/)
- [02_initial](/mms-wiki/programs-and-tools/md-info/scripts/02_initial/)
- [03_MD](/mms-wiki/programs-and-tools/md-info/scripts/03_MD/)

## Scope and purpose

This workflow was initially developed for a demanding membrane-protein system, namely ASIC1a embedded in a lipid bilayer. Because membrane systems can be difficult to equilibrate and are often computationally expensive, the scripts were designed with robustness and restart safety in mind.

Even so, the general ideas are broadly reusable:

- preparation of a simulation-ready system
- staged equilibration
- checkpoint-based production runs
- clean resubmission under Slurm walltime limits
- optional scratch usage for performance
- preservation of restart-critical files on persistent storage

## Important note before reuse

These scripts are meant to be adapted to each user’s own system and directory organization.

In particular, before reusing them, users should review and adapt:

- local directory paths
- Slurm account and partition names
- CPU and memory settings
- container location
- force-field directory
- starting structures and topology names
- whether the job will run in CPU or GPU mode

No user-specific absolute paths should be copied blindly.

## Recommended philosophy

The production workflow follows an 8-hour rotation logic:

- submit jobs with an 8-hour walltime
- make GROMACS stop early with `-maxh`
- write checkpoints regularly
- automatically resubmit clean stops
- continue from checkpoints with `-cpi ... -append`

This allows fairer shared use of the cluster while still supporting long trajectories.

## Notes for simpler systems

The initialization shown in this workflow was developed for a particularly difficult membrane system.

For many simpler systems, initialization can often be reduced to:

- a short 1 fs position-restrained equilibration
- followed by a short 2 fs position-restrained equilibration

before moving on to the same production framework described here.