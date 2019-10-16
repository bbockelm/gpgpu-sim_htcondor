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
