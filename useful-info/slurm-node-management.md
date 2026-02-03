---
layout: page
title: Slurm node management
pinned: false
---

This page documents common **Slurm node management commands** used to temporarily
remove compute nodes from scheduling (for example, during maintenance) and to
bring them back into service once they are ready.

> **Important**  
> The commands below typically require **Slurm operator or administrator
> privileges**. Regular users will receive a permission error or see no effect.

> **Note on node names**  
> In the examples below, `bioXXX` refers to a generic compute node name.  
> Replace `XXX` with the numeric identifier of the machine you intend to manage
> (e.g. `bio007`, `bio012`, `bio031`).

---

## 🔍 Checking node status

Before changing the state of a node, always inspect its current status.

```bash
scontrol show node bioXXX
```

```bash
sinfo -n bioXXX
```

These commands allow you to:
- identify the current node state (`IDLE`, `ALLOCATED`, `DRAIN`, `DOWN`, …)
- see whether jobs are currently running
- read any reason messages associated with the node state

---

## 🚧 Taking a node out of the queue (recommended: `DRAIN`)

To **prevent new jobs from being scheduled** on a node while allowing currently
running jobs to finish naturally, place the node in the `DRAIN` state.

```bash
sudo scontrol update NodeName=bioXXX State=DRAIN Reason="maintenance"
```

Typical use cases include:
- planned maintenance
- operating system updates
- hardware inspection or replacement
- temporary instability or debugging

Once drained, the node will no longer accept new jobs.

---

## ⛔ Forcing a node unavailable (`DOWN`)

To mark a node as **immediately unavailable**, use the `DOWN` state.

```bash
sudo scontrol update NodeName=bioXXX State=DOWN Reason="maintenance"
```

⚠️ **Use with care**:
- jobs may require manual cleanup
- administrator intervention may be needed to recover job state
- this is typically reserved for hardware failures or urgent intervention

---

## ✅ Putting a node back into service (`RESUME`)

After maintenance or troubleshooting is complete, return the node to the
scheduler using `RESUME`.

```bash
sudo scontrol update NodeName=bioXXX State=RESUME
```

This clears the `DRAIN` or `DOWN` state and allows the node to accept new jobs
again.

---

## ✔️ Verifying the change

After updating the node state, always confirm that the change was applied
successfully.

```bash
sinfo -n bioXXX
```

Expected states after a successful `RESUME`:
- `IDLE` — node is available for scheduling
- `ALLOCATED` — node is running jobs

---

## 📝 Notes and best practices

- Prefer **`DRAIN` over `DOWN`** for planned maintenance.
- Always include a **Reason** string; it is visible in `sinfo` output and helps
  other administrators understand the node status.
- Ensure that `slurmd` is running on the node before issuing `RESUME`.
- If a node does not return to `IDLE` after `RESUME`, check:
  - `slurmd` logs on the node
  - connectivity to the Slurm controller
  - MUNGE authentication

---

## 🔗 See also

- `man scontrol`
- `man sinfo`
- [Cluster-specific operational guidelines](../useful-info/cluster-good-practices.md)
