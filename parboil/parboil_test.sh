#!/bin/sh

# Unpack the CUDA files we will need:
tar zxf cuda_files.tar.gz

# Set the environment variable LD_LIBRARY_PATH so we can find the driver

export CUDA_INSTALL_PATH=$PWD/cuda_files/cuda-9.1
export LD_LIBRARY_PATH=$CUDA_INSTALL_PATH/lib
export CUOBJDUMP_SIM_FILE=jj

# Some debugging to help us out
ls -l

# Finally, execute parboil.
exec ./parboil-cutcp -i watbox.sl40.pqr -o lattice.dat
