#!/bin/bash
# Write output as following (%j is JOB_ID) - todo param name?
#SBATCH -o cluster_brain-%j.out

if [[ $# -ge 2 ]]; then
  dataset_path=$1
  python_script=$2
else
  echo "Error. Please give data folder (relative to 2p folder)"
  exit 1
fi

input_args=$@ # save if needed
shift $# # remove arguments - this is preventing bug in source usage below

if [ -n $SLURM_JOB_ID ];  then
    # check the original location through scontrol and $SLURM_JOB_ID
    SCRIPT_PATH=$(scontrol show job $SLURM_JOBID | awk -F= '/Command=/{print $2}' | cut -f1 -d " ")
else
    # otherwise: started with bash. Get the real location.
    SCRIPT_PATH=$(realpath $0)
fi
path=$(dirname $SCRIPT_PATH)

# get script's path to allow running from any folder without errors
source ~/anaconda3/bin/activate
conda init

# use libs installed in caiman (need tiff mostly)
conda activate caiman

# code => scripts => raw to till
python $path/../python_scripts/$python_script $dataset_path

conda deactivate
