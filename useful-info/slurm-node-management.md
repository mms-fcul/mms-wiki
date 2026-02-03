---
layout: page
title: Slurm node management
pinned: false
---

This page documents common Slurm node management commands used to temporarily
remove compute nodes from scheduling (e.g. for maintenance) and to bring them
back into service.

IMPORTANT:
The commands below typically require Slurm operator or administrator privileges.
Regular users will receive a permission error or see no effect.

NOTE:
In the examples below, bioXXX refers to a generic compute node name.
Replace XXX with the numeric identifier of the machine you intend to manage
(e.g. bio007, bio012, bio031).

------------------------------------------------------------

CHECK NODE STATUS

Before changing the state of a node, always check its current status.

Command:
scontrol show node bioXXX

Command:
sinfo -n bioXXX

These commands show:
- current node state (IDLE, ALLOCATED, DRAIN, DOWN, etc.)
- running jobs
- reason messages (if the node is drained or down)

------------------------------------------------------------

TAKE A NODE OUT OF THE QUEUE (RECOMMENDED: DRAIN)

To stop new jobs from being scheduled on a node while allowing currently running
jobs to finish, use DRAIN.

Command:
sudo scontrol update NodeName=bioXXX State=DRAIN Reason="maintenance"

Typical use cases:
- planned maintenance
- OS updates
- hardware inspection
- temporary instability

Once drained, the node will not accept new jobs.

------------------------------------------------------------

FORCE A NODE UNAVAILABLE (DOWN)

To mark a node as unavailable immediately, use DOWN.

Command:
sudo scontrol update NodeName=bioXXX State=DOWN Reason="maintenance"

WARNING:
- jobs may require manual cleanup
- admin intervention may be needed to recover job state
- typically used for hardware failure or urgent intervention

------------------------------------------------------------

PUT A NODE BACK INTO SERVICE (RESUME)

After maintenance is complete, bring the node back into the scheduler with RESUME.

Command:
sudo scontrol update NodeName=bioXXX State=RESUME

This clears the DRAIN or DOWN state and allows the node to accept new jobs again.

------------------------------------------------------------

VERIFY THE CHANGE

After any state update, verify that the node is available.

Command:
sinfo -n bioXXX

Expected states after RESUME:
- IDLE (available)
- ALLOCATED (running jobs)

------------------------------------------------------------

NOTES AND BEST PRACTICES

- Always prefer DRAIN over DOWN for planned maintenance.
- Always include a Reason string (it appears in sinfo and helps other admins).
- Ensure that slurmd is running on the node before using RESUME.
- If a node does not return to IDLE after RESUME, check:
  - slurmd logs on the node
  - connectivity to the Slurm controller
  - MUNGE authentication

------------------------------------------------------------

SEE ALSO

- man scontrol
- man sinfo
- Cluster-specific operational guidelines:
  ../useful-info/cluster-good-practices.md
