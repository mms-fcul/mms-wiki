---
layout: page
title: What machines we have and what they are for
permalink: /useful-info/cluster/
---

You can find more about the diferent machines that make up out cluster by running the 
```
s-hosts
```
command. It lists all the machines according to their partition and shows relevant information regarding the machines.

## Partitions

## CPUs
The amount of CPUs available for the slurm to manage. This doesn't necessarily correspond to the total amount of CPUs of the machine, specially for those located in the workspace (otherwise there would be no more cores to dedicate to all the other tasks you are doing right now, including having this window open). 

## Load
Shows the real time average load of the machine. This is the amount of **actual** cores being used. For instance a value of 6.5 should be interpreted as 6.5 cores in use. This could be due to the machine running a 6 core slurm job along side other processes (running outside of slurm) that only take half a core. 
For machines in the workspace it is possible for the load to exceed the amount of available CPU cores shown, but remember that those are only the dedicated slurm cores, it is likely the machine posses more than the cores shown. 

## Mem(GB)
Shows the RAM allocation (in GB) for each machine. The RAM requirements of a job depends, regardles if a machine has no memory available it is not recomended to run additional jobs.

## Cluster status
If this information is being show the machine is properly running as part of slurm, but that is not always the case. Some machines may have some hardware issue and be down for repair, have been rebooted or be offline all together. These statuses obscure the system resources because they are not in the slurm queue and thus are not being monitored. In order to get the real occupation you need to tunnel into the machine (`ssh bioXXX`) and analyse the `top` output. You will find that it provides more information than `s-hosts`, including the information on load and CPU usage discussed previously.



