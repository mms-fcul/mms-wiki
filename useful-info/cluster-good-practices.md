---
layout: page
title: Cluster Good Practices
permalink: /useful-info/cluster-good-practices/
---

# Taking advantage of local disks
Our cluster's infrastructure is split between the computers in the workspace (and nearby offices) and the computers in the computational center in the C1 building.

## Local disks vs Remote disks
Unlike what is usual in personal machines, your files (`/home`) are not actually in the computer you are looking at and using right now. They are actually in the disks in `bio000` in the C1 building and are accessed over the network everytime you need them. This is how you can log in to any workstation and have your files waiting right where you left them: its not like they are in all of the computers, they are actually only on bio000.

## /tmp can be your best friend
The fact that your `/home` is not in your local disk means that when you process and write (change and save) a file it needs to be retrieved from the correct directory in bio000 (in C1), be processed by your local CPU and sent back. This retrieval time is substancially slower than the time between a CPU and the local hard drive of its machine. To illustrate this lets take the processing of a trajectory as an example.
You performed a simulation with slurm and wrote the results to a folder in your home directory (located in /home in bio000). You are now performing a trajectory analysis with a protocol that goes something like:
```
gro ---> aux1 ---> traj
```
If you perform this analysis in bio161 (for example) the path the files will take will be something like:
```
bio000 --> bio161 ----------> bio000 ------> bio161 -----> bio000
reading -> processing -> writting reading -> processing -> writting
gro -------------------------> aux1 ---------------------> traj
```
These files need to travel back and forth between the two buildings for each file that is read and written. In this example that makes up a total of four trips. Now let's consider an alternative protocol where we instead use the local /tmp disk as a scratch disk instead of /home:
```
/home ---> /tmp -----------------------------------------------------> /home
bio000 --> bio161 ---------------------------------------------------> bio000
reading -> processing -> writting reading -> processing -> writting -> copying
gro -------------------------> aux1 ---------------------> traj
               5                               1                          1 min
```
By performing all the calculations on the `/tmp` disk and only copying at the end we save a lot of time otherwise spend reading and writting files over ethernet. This has such a big impact that **total analysis time can be reduced from 2 to 10 times**.
