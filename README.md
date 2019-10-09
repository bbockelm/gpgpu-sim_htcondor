
Getting started with GPGPU-Sim on CHTC
======================================


Prepare the GPGPU-Sim build
---------------------------

1.  Prepare an empty work directory:

   ```
   mkdir -p ~/projects/gpgpu-sim-v2    # Create a top-level directory
   cd ~/projects/gpgpu-sim-v2          # Change to that directory
   mkdir gpgpu-sim-v2/condor_workdir   # Create a scratch directory for condor files.
   ```

2.  Check out the GPGPU-sim sources and switch to the `dev` branch:

   ```
   git clone https://github.com/gpgpu-sim/gpgpu-sim_distribution
   git clone https://github.com/gpgpu-sim/gpgpu-sim_simulations
   cd gpgpu-sim_distribution
   git checkout dev
   ```

   You may need to adjust to the exact commit or release tag that you are
   interested in working with.

3.  Convert the GPGPU-sim source code to a tarball:

    ```
    git archive --format tar.gz --output ../condor_workdir/gpgpu-sim_distribution.tar.gz --prefix gpgpu-sim_distribution/ dev
    cd ../gpgpu-sim_simulations
    git archive --format tar.gz --output ../condor_workdir/gpgpu-sim_simulations.tar.gz --prefix gpgpu-sim_simulations/ HEAD
    ```

4.  Now, we'll submit a HTCondor "build" job to start the process of putting together our binary
    tarball.  Create the following submit description file in `condor_workdir` and name it
    `interactive.sub`:

    ```
    universe = vanilla
    # Name the log file:
    log = interactive.log

    # Name the files where standard output and error should be saved:
    output = process.out
    error = process.err

    # If you wish to compile code, you'll need the below lines. 
    #  Otherwise, LEAVE THEM OUT if you just want to interactively test!
    +IsBuildJob = true
    requirements = (OpSysMajorVer =?= 7)

    # Indicate all files that need to go into the interactive job session,
    #  including any tar files that you prepared:
    transfer_input_files = gpgpu-sim_distribution.tar.gz, gpgpu-sim_simulations.tar.gz

    # It's still important to request enough computing resources. The below 
    #  values are a good starting point, but consider your file sizes for an
    #  estimate of "disk" and use any other information you might have
    #  for "memory" and/or "cpus".
    request_cpus = 1
    request_memory = 4GB
    request_disk = 4GB
    request_gpus = 1

    queue
    ```

    Once the submit description file is created, then we can submit it as an interactive job:

    ```
    condor_submit -i interactive.sub
    ```

    It will typically take 1-2 minutes for this job to startup, depending on the availability
    of GPU nodes.

5.  Once the interactive job has started, you'll have a fresh shell on the GPU host.  First,
    set the path to the CUDA toolkit you would like to use and unpack our source tarball:

    ```
    export CUDA_INSTALL_PATH=/usr/local/cuda-9.1
    tar zxf gpgpu-sim_distribution.tar.gz
    tar zxf gpgpu-sim_simulations.tar.gz
    cd gpgpu-sim_distribution/
    ```

    *WARNING*: GPGPU-Sim does not always support the latest CUDA toolkit version.  Prefer
    a version-specific install directory (such as `/usr/local/cuda-9.1`) as opposed to the
    latest version (`/usr/local/cuda`).

    Next, setup the GPGPU-Sim build environment:

    ```
    source setup_environment
    ```

    Type `make` to build GPGPU-Sim:

    ```
    make -j4
    ```

    Next, change directories to the simulations:

    ```
    cd ../gpgpu-sim_simulations/
    ```

    You will need to download the sample data, setup the environment, and make the appropriate
    benchmark:

    ```
    cd benchmarks
    ./get_data.sh   # This is a 2.5GB download; may take a few minutes to complete.
    cd src
    source setup_environment
    make parboil
    ```

6.  Finally, we'll prepare a directory structure with all the files necessary for GPGPU-Sim:

    ```
    cd ../../..
    mkdir -p cuda_files/cuda-9.1/{bin,lib}
    cp $CUDA_INSTALL_PATH/bin/ptxas cuda_files/cuda-9.1/bin/
    cp $CUDA_INSTALL_PATH/bin/cuobjdump cuda_files/cuda-9.1/bin/
    cp lib/gcc-4.8.5/cuda-9010/release/libcudart.so.9.1 cuda_files/cuda-9.1/lib/
    tar zcf cuda_files.tar.gz cuda_files
    cp gpgpu-sim_simulations/benchmarks/bin/9.1/release/parboil-cutcp .
    ```

    HTCondor will automatically transfer back any _files_ - not directories - left at the
    top-level scratch directory.  Thus, `cuda_files.tar.gz` will be transferred back once
    `Ctrl+C` is hit.

7.  Hit `Ctrl+C`; this will return you to the login host.  There should be two new files in your
    `condor_workdir`:

    * `cuda_files.tar.gz`: The runtime for GPGPU-Sim.
    * `parboil-cutcp`: The example binary we will use for our testing.

Running GPGPU-Sim on HTCondor
-----------------------------

Now that we have prepared a software runtime (`cuda_files.tar.gz`) and a sample executable (`parboil-cutcp`),
will now do a full run of `parboil-cutcp` inside HTCondor.

First, we will need to prepare a few input files; they are contained in this git repository:

* `watbox.sl40.pqr`: An input file for `parboil-cutcp` itself.
* `SM2_GTX480`: A directory containing the GPGPU-Sim configurations for the GTX480 (these
  configurations were taken from `gpgpu-sim_distribution/configs/tested-cfgs/SM2_GTX480`).  Within
  this directory are the three files necessary to simulate the GTX480, `config_fermi_islip.icnt`,
  `gpgpusim.config`, and `gpuwattch_gtx480.xml`.

Additionally, we will need to prepare a submit description file that will tell HTCondor how to
setup the job environment - and a script for the worker node itself.

First the submit description file.  Copy the following to `parboil_test.sub`:

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
# and parboil-cutcp for this example.
# NOTE: the gpgpu-sim configuration files are a macro; to be
# defined later.

# This is the directory that all the `transfer_input_files` will be relative to;
# We start inside a results directory and pull inputs from the parent directory.
# You may want a distinct `initialdir` per job run.
initialdir = $(gpgpusim_configdir)-results
transfer_input_files = ../cuda_files.tar.gz, ../watbox.sl40.pqr, ../parboil-cutcp, ../$(gpgpusim_configdir)/

# The name of the wrapper script
executable = parboil_test.sh

# The filenames for stdout, stderr, and HTCondor logging information.
output = parboil.out
error = parboil.err
log = parboil.log

# Finally, the macro that controls the name of the configuration directory; vary this,
# and you will change where the inputs come from above
gpgpusim_configdir = SM2_GTX480

queue 1
```

Output files will go into `SM2_GTX480-results`; ensure that exists:

```
mkdir -p SM2_GTX480-results
```

Finally, we need the `parboil_test.sh` script that HTCondor will run on the worker node:

```
#!/bin/sh

# Unpack the CUDA files we will need:
tar zxf cuda_files.tar.gz

# The GPGPU-Sim will look for this environment variable name to find the necessary
# NVIDIA runtime binaries.
export CUDA_INSTALL_PATH=$PWD/cuda_files/cuda-9.1

# Set the environment variable LD_LIBRARY_PATH so the parboil-cutcp executable
# will find the libcudart.so driver from GPGPU-Sim
export LD_LIBRARY_PATH=$CUDA_INSTALL_PATH/lib

# This environment variable must be set for GPGPU-Sim to invoke cuobjdump as expected
export CUOBJDUMP_SIM_FILE=jj

# Finally, execute parboil.
exec ./parboil-cutcp -i watbox.sl40.pqr -o lattice.dat
```
