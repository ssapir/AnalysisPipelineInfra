#!/bin/bash
set -e

################# Parameters ############################
scripts_dir=`dirname $(realpath $0)`/slurm_files/
dataset_path='.../Data/2p/'

if [[ "$#" -ge 1 ]]; then
  data_folder=$1
else
  echo "Error. Lacking input data as 1st parameter"
  exit 1
fi

echo "Running on $1"

################# Main (pipeline build, run 'squeue --me' to follow jobs) ##
is_tiffs_lacking=0
if [[ ! -d "$dataset_path/$data_folder/tiffs" ]] ; then # todo check if all files were created?
   is_tiffs_lacking=1
   echo "Lacking $dataset_path/$data_folder/tiffs"
fi

name=$(echo $data_folder | sed 's@/@_@g')
dependency=""

# run tiff and save as dep if not alreay created
if [[ "$is_tiffs_lacking" -eq 1 ]] ; then
  echo "Tiffs are lacking. Recreating folder:"
  jobarrout=$(sbatch --mem="55G" --job-name=$name-tiffs $scripts_dir/run_general_python_script.sh $dataset_path/$data_folder create_tiff_from_raw_data.py)
  jobarrid=$(echo $jobarrout | rev| cut -d ' ' -f1 | rev)
  echo "id $jobarrid from $jobarrout "
  dependency="--depend=afterany:$jobarrid"
fi

# raw traces after tiff is ok
$jobarrout(sbatch --mem="180G" --job-name=$name-neuron-traces $dependency $scripts_dir/run_general_python_script.sh $dataset_path/$data_folder extract_raw_and_motion_corr_traces.py)
jobarrid_traces=$(echo $jobarrout | rev| cut -d ' ' -f1 | rev)

# run visualization after prev job ended
if [[ "$is_tiffs_lacking" -eq 0 ]] ; then  # check if we need to dep on tiff creation as well (1) or only on thor sync (0)
    dependency="--depend=afterany"
fi
sbatch --mem="50G" --job-name=$name-vis-caiman $dependency:jobarrid_traces $scripts_dir/run_general_matlab_script.sh $dataset_path $data_folder visualize_raw_data_and_stimulus ",true,true,100,2"