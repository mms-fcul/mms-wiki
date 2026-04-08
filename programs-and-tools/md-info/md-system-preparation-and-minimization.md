---
layout: page
title: MD - System Preparation and Minimization
pinned: false
permalink: /programs-and-tools/md-info/md-system-preparation-and-minimization/
---

This page describes the first stage of the molecular dynamics workflow: preparing a simulation-ready system and minimizing it before equilibration.

## Purpose

The goal of this stage is to transform the original structural inputs into a consistent GROMACS system containing:

- the protein
- the membrane
- solvent
- ions
- topology and index files
- minimized coordinates for later initialization

For the original ASIC membrane workflow, the starting point was a CHARMM-GUI membrane system, which then had to be adapted to match the force-field and CpHMD-compatible naming conventions used later in the workflow.

## Files used in this stage

- `01_prepare-system.sh`
- `02_run-pdb2gmx.sh`
- `03_index.sh`
- [`04_min.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/01_box-min/04_min.sh)
- [`min1.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/01_box-min/min1.mdp)
- [`min2.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/01_box-min/min2.mdp)

Note that the earlier system-preparation scripts are highly system-specific and are not currently included in this shared folder.

## What each script does

### `01_prepare-system.sh`

This script prepares the protein PDB that will later be used by [`02_run-pdb2gmx.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/01_box-min/02_run-pdb2gmx.sh).

Its role is to:

- extract the protein coordinates from the larger assembled system
- split chains correctly by inserting `TER` records
- assign chain identifiers
- clean up terminal atom handling
- generate a protein-only PDB suitable for topology generation

Because this logic depends strongly on the structure and naming conventions of the original input, users should inspect and adapt this script carefully when applying it to a different system.

### `02_run-pdb2gmx.sh`

This script runs `gmx pdb2gmx` inside the container to generate a protein topology and structure compatible with the chosen force field.

It then merges the rebuilt protein coordinates with the membrane/solvent coordinates from the assembled membrane system and creates:

- a combined `.gro` file
- a combined `.top` file

This step also includes topology edits to ensure that membrane, solvent, and ion naming match the chosen force-field setup.

### `03_index.sh`

This script generates the index file used in later stages.

Typical groups created here include:

- membrane
- water
- ions
- solvent
- solute

These groups are important for restrained equilibration, coupling choices, and analysis.

### [`04_min.sh`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/01_box-min/04_min.sh)

This script runs a two-step minimization protocol.

In the original workflow:

- the first minimization starts from the assembled system
- the second minimization starts from the output of the first

The exact details are controlled by [`min1.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/01_box-min/min1.mdp) and [`min2.mdp`](https://github.com/mms-fcul/mms-wiki/blob/main/programs-and-tools/md-info/scripts/01_box-min/min2.mdp).

## Typical order of execution

A typical usage sequence is:

```bash
./01_prepare-system.sh
./02_run-pdb2gmx.sh
./03_index.sh
./04_min.sh 8
```

Replace 8 with the number of CPU threads appropriate for your system.

## What should be adapted locally

Before reuse, users should adapt:
- structure input paths
- base project directories
- force-field locations
- container locations
- system names
- topology naming assumptions
- any force-field-specific sed or text-replacement logic

## Final output of this stage

At the end of this stage, the user should have:
- a merged system structure
- a matching topology
- an index file
- minimized coordinates

These files serve as the input for the [initialization/equilibration](/mms-wiki/programs-and-tools/md-info/md-initialization-and-equilibration/) stage.