# AnalysisPipelineInfra
Common functions and infrastructure built during my PhD projects 
(custom-made automatic-tracking based on computer vision, caiman-based 2p-Ca analysis pipeline, neuron-based simulations)

## Overview
The main script is run_analysis_pipeline.sh, as an example of a slurm-based pipeline.

In addition, utils folder contains my opencv-based common functions (tbd add more)

(For my phd I used parameter files passed to the main script for more flexibility. Not added here due to privacy)

### Pipeline supporting scripts
Scripts used by run_analysis_pipeline.sh:
* python_scripts - contains help scripts:
  * create_tiff_from_raw_data.py: prepare data (.raw format to tiffs) for caiman's code.
  * extract_raw_and_motion_corr_traces.py: creates data traces from caiman's output (hdf5 and mat files) as a mat file.
* matlab_functions folder contains functions triggered by the pipeline:
  * visualize_raw_data_and_stimulus.m: movie visualization of raw data (from tiff files), annotated with stimulus

 #### Add script/stage to the pipeline
 * Matlab: sbatch $scripts_dir/run_general_matlab_script.sh $dataset_path $data_folder <matlab function name> "<additional args if needed, sep by comma>"
 * Python: sbatch $scripts_dir/run_general_python_script.sh $dataset_path/$data_folder <python script name>
    * Can add later support for additional parameters (currently not needed)
 * Both can get the following additional slurm parameters, s.a --mem, --job-name, --depend (see run_analysis_pipeline.sh for example)
