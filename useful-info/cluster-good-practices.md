---
layout: page
title: Cluster Good Practices
permalink: /useful-info/cluster-good-practices/
---

# Taking advantage of local disks

Our cluster infrastructure is split between:
- workstations in the workspace (and nearby offices), and
- compute nodes in the C1 computational center.

Understanding where your data lives — and how it moves — is essential for both
performance and responsible resource usage.

---

## Local disks vs remote disks

Unlike personal machines, your `/home` directory is **not stored locally** on the
machine you are logged into. Instead, it resides on the disks of `bio000` (C1)
and is accessed over the network.

This design allows you to log into any workstation and find your files exactly
where you left them. However, it also means that **frequent reads and writes to
`/home` are slower** than local disk access.

---

## `/tmp` can be your best friend

When a file in `/home` is accessed, it must:
1. travel from `bio000` to the local machine,
2. be processed by the CPU,
3. and be written back over the network.

This is significantly slower than working on a local disk.

### Example: trajectory processing

A typical analysis workflow might look like:

```
gro → aux1 → traj
```

If performed directly in `/home`, data repeatedly travels between buildings, doing something like:
```
bio000 --> bio161 ----------> bio000 ------> bio161 -----> bio000
reading -> processing -> writting reading -> processing -> writting
gro -------------------------> aux1 ---------------------> traj
              5                                5 min
```

Using the local `/tmp` directory as a scratch space allows all intermediate I/O
to happen locally, with only the final results copied back to `/home`.

```
/home ---> /tmp -----------------------------------------------------> /home
bio000 --> bio161 ---------------------------------------------------> bio000
reading -> processing -> writting reading -> processing -> writting -> copying
gro -------------------------> aux1 ---------------------> traj
               5                               1                          1 min
```

In practice, this can reduce total analysis time by a factor of **2–10×**.

---

# Storage usage and data lifecycle

Efficient storage usage is critical for cluster sustainability and performance.

> **Guideline**  
> Each user should aim to occupy **less than 1 TB** of total storage.

Users exceeding this value should prioritise analysing results, publishing, and
archiving completed projects.

---

## Active vs archived projects

### Active projects
Projects that are:
- currently running,
- under active analysis,
- or being iteratively refined.

These should remain in high-performance storage locations.

### Archived projects
Projects for which:
- main simulations are complete,
- results are published or close to publication,
- no further large-scale computation is expected.

Archived projects **must be moved to `/work`** after proper data reduction.

---

## Data reduction before archiving

Raw molecular dynamics output often contains far more data than required for
analysis or reproducibility.

Before archiving:
- remove temporary and intermediate files,
- keep only scientifically meaningful outputs,
- reduce trajectory size whenever possible.

In MD simulations, the main contributors to excessive storage usage are:
- overly frequent trajectory output,
- full solvent trajectories,
- duplicated files in multiple formats,
- equilibration data that is rarely reused.

---

# Practical recommendations for GROMACS users

The guidelines below apply to both **soluble proteins** and **membrane systems**
and focus on **safe, conservative data reduction**.

---

## What you should always keep

- Final structures (`.gro`, `.pdb`)
- Topology and parameter files (`.top`, `.itp`)
- Production `.mdp` and `.log` files
- Final (possibly reduced) trajectories
- Scripts used for simulations and analysis

---

## What can usually be removed

- Temporary or intermediate files
- Backup files (`#file#`, `file~`)
- Equilibration trajectories
- Duplicate trajectory formats
- Failed or test runs

---

## Step 1 — Clean and centre trajectories

```bash
gmx trjconv -s topol.tpr -f traj.xtc -o traj_clean.xtc -pbc mol -center
```

Centre on `Protein`; output group: `System`.

---

## Step 2 — Reduce frame frequency

```bash
gmx trjconv -s topol.tpr -f traj_clean.xtc -o traj_dt100ps.xtc -dt 100
```

Typical values:
- 10–50 ps for analysis
- 100 ps for long-term storage

---

## Step 3 — Remove solvent (keep ions when needed)

Solvent dominates trajectory size. Removing it can reduce disk usage by **5–20×**.

### Soluble proteins
```bash
gmx make_ndx -f md.gro -o index.ndx
gmx trjconv -s topol.tpr -f traj_dt100ps.xtc -n index.ndx -o traj_solute.xtc
```

Select a group containing protein (and ligands/ions if required).

### Membrane systems
```bash
gmx make_ndx -f md.gro -o index.ndx
gmx trjconv -s topol.tpr -f traj_dt100ps.xtc -n index.ndx -o traj_PM.xtc
```

Select a Protein + Membrane (+ ions) group.

---

## Step 4 — Validate before deleting raw data

```bash
gmx check -f traj_solute.xtc
```

Ensure trajectories load correctly and contain the expected atoms.

---

## Compressing analysis outputs

Analysis results are usually small but can accumulate over time.

General recommendations:
- keep final results only,
- compress text-based files (`.csv`, `.dat`, `.txt`),
- bundle related outputs into a single archive.

Examples:

Compress text files:
```bash
gzip results.csv
```

Archive a directory of plots or tables:
```bash
tar -czf analysis-results.tar.gz analysis/
```

Scripts are generally more valuable than intermediate outputs; results should be
easy to regenerate when possible.

---

## Before moving projects to `/work`

Before archiving:
- validate reduced data,
- remove redundant files,
- compress analysis outputs.

Only clean, curated projects should be moved to `/work`.

---

## See also

- `man gmx-trjconv`
- `man scontrol`
