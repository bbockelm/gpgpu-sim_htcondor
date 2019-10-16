
Running GPGPU-Sim with backprop on HTCondor
===========================================

Setup
-----

In this tutorial, we'll run the `backprop` benchmark using GPGPU-Sim inside a HTCondor job.

First, get a copy of the software runtime (`cuda_files.tar.gz`) and the sample executable (`backprop`).

If you are using the copies we have prepared for the class, you can find both files in `/srv/sinclair` on
the login host; otherwise, see the `build_instructions` subdirectory for making your own.

If you are using the prepared versions, copy them to the current directory:

```
cp /srv/sinclair/cuda_files.tar.gz /srv/sinclair/backprop .
```

Next, we will need a few configuration files; they are contained in this git repository
in the `SM2_GTX480` directory.  This contains the GPGPU-Sim configurations for the GTX480 (these
configurations were taken from `gpgpu-sim_distribution/configs/tested-cfgs/SM2_GTX480`).  Within
this directory are the three files necessary to simulate the GTX480, `config_fermi_islip.icnt`,
`gpgpusim.config`, and `gpuwattch_gtx480.xml`.

Additionally, we will need to prepare a submit description file that will tell HTCondor how to
setup the job environment - and a script for the worker node itself.

First the submit description file.  Copy the following to `backprop_test.sub`:

```
# Loosely modeled on the starter submit file here:
#   http://chtc.cs.wisc.edu/helloworld.shtml

# Type of job we will be running
universe = vanilla

# Resource requirements we need for this job
request_cpus = 1
request_memory = 2GB
request_disk = 1GB

# Specify the policy for moving files between the execute
# and submit environments
should_transfer_files = YES
when_to_transfer_output = ON_EXIT

# Finally, which files to transfer.  We'll be using CUDA
# and backprop for this example.
# NOTE: the gpgpu-sim configuration files are a macro; to be
# defined later.
initialdir = $(gpgpusim_configdir)-results
transfer_input_files = ../cuda_files.tar.gz, ../backprop, ../$(gpgpusim_configdir)/

# We do not specify `transfer_output_files`; accordingly *all* files created in the
# top-level job directory will be copied to the `initialdir` specified above when
# the job completes.

# For backprop, the argument is the network size; increasing this (must be divisible
# by 16) will increase the runtime.  The value 8192 should result in a 2 minute runtime.
arguments = 8192
executable = backprop_test.sh

# Filenames for output; recall this will be put into $(initialdir), not the
# submit directory.
output = backprop.out
error = backprop.err

# Condor's logging for the job will go to this file.
log = backprop.log

# Name of the configuration directory to use.
gpgpusim_configdir=SM2_GTX480

queue 1
```

Output files will go into `SM2_GTX480-results`; ensure that exists:

```
mkdir -p SM2_GTX480-results
```

Finally, we need the `backprop_test.sh` script that HTCondor will run on the worker node:

```
#!/bin/sh

# Unpack the CUDA files we will need:
tar zxf cuda_files.tar.gz

# The GPGPU-Sim will look for this environment variable name to find the necessary
# NVIDIA runtime binaries.
export CUDA_INSTALL_PATH=$PWD/cuda_files/cuda-9.1

# Set the environment variable LD_LIBRARY_PATH so the backprop executable
# will find the libcudart.so driver from GPGPU-Sim and the various dynamic libraries
# it needs.
export LD_LIBRARY_PATH=$CUDA_INSTALL_PATH/lib

# This environment variable must be set for GPGPU-Sim to invoke cuobjdump as expected
export CUOBJDUMP_SIM_FILE=jj

# Finally, execute backprop with the argument provided by the submit file.
exec ./backprop $1
```

Running
-------

To submit the job, use `condor_submit`:

```
condor_submit backprop_test.sub
```

Refer to the lecture slides on HTCondor to help track job progress.  Recall:

   - Logging for the `SM2_GTX480` run will be placed into `SM2_GTX480-results` directory.
   - Interaction with the job queue is done with `condor_q`; see the CHTC resources for
     [submitting simple jobs](http://chtc.cs.wisc.edu/helloworld.shtml) or [`condor_q` itself](http://chtc.cs.wisc.edu/condor_q.shtml)
   - If a job goes on hold, it means there is an issue which likely requires human intervention
     to resolve; see the output of `condor_q -held`.
   - Use `condor_ssh_to_job` to get an interactive terminal to a running job.
   - If you submit multiple jobs using the above configuration file, they will all overwrite
     the same set of files (not append!).  You can use the `$(ClusterId)` macro to ensure the
     logfiles are unique.
   - To ensure the output directories are unique, try the [multiple job directories guide](http://chtc.cs.wisc.edu/multiple-job-dirs.shtml)
     on the CHTC website.
