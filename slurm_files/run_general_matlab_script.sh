#!/bin/bash
# Write output as following (%j is JOB_ID)
#SBATCH -o cluster_brain_matlab-%j.out

if [[ $# -ge 3 ]]; then
  dataset_path=$1
  sub_folder_path=$2
  matlab_script=$3
else
  echo "Error. Please give data folder (relative to 2p folder)"
  exit 1
fi

args=""
if [[ $# -ge 4 ]]; then
   args=$4
fi

input_args=$@ # save if needed
shift $# # remove arguments - this is preventing bug in source usage below

# Deactivating the CL args to enable sourcing in the script
set --

if [ -n $SLURM_JOB_ID ];  then
    # check the original location through scontrol and $SLURM_JOB_ID
    SCRIPT_PATH=$(scontrol show job $SLURM_JOBID | awk -F= '/Command=/{print $2}' | cut -f1 -d " ")
else
    # otherwise: started with bash. Get the real location.
    SCRIPT_PATH=$(realpath $0)
fi
path=$(dirname $SCRIPT_PATH)

# move to matlab functions folder to find code
cd $path/../matlab_functions/

matlab -nodesktop -nosplash -noFigureWindows -batch "$matlab_script""('"$sub_folder_path"','"$dataset_path"'$args); exit"
