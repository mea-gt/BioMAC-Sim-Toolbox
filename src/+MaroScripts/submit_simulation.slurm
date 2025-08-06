#!/bin/bash -l
#
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --time=08:00:00
#SBATCH --job-name=${INPUT1}_${INPUT2}_${INPUT3}
#SBATCH --output=slurm-%x-%j.out

# load module (check Matlab versions with "module avail")
module load matlab/R2023b

# build matlab code which should be called
WORKDIR="'~/OptCntrlSims/BioMAC-Sim-Toolbox/'"
PATHIPOPT="'~/IPOPT-toolbox/'"
FUNCTION="MaroScripts.scriptCODfromMeasIMU"
MATLABCODE="addpath(genpath(${PATHIPOPT})); addpath(genpath(${WORKDIR})); ${FUNCTION}(${WORKDIR}, '${INPUT1}', '${INPUT2}', '${INPUT3}'); quit;"
echo ${MATLABCODE}

# submit job
matlab -nojvm -nodisplay -nosplash -r "${MATLABCODE}"
