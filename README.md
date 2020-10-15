# Stoch_Unit_Commitment_For_DR
Two stage stochastic unit commitment model for demand response. 

Please cite as:
Patricia Levi and John Weyant, "Assessing the relative properties of Demand Response in electricity systems," _in prep_, 2020.

Related Presentations and Documents:
* A
* B

## Overview 
The main stochastic unit commitment model is written in Julia 0.6.4, and the post-processing scripts are written in R. The assumed base folder name is '~/dr_stoch_uc/'.

The inputs/ folder contains three folders:
1. `<test_multi/>` has inputs for a small test case with just a few hours
2. `<ercot_default/>` contains inputs that are used for all ercot 2016 runs: this data is specific to the generators available, and contains 2016 demand
3. `<5d_6o_keyDays2/>` contains inputs needed for a specific selection of time windows to run (keyDays2), organized into 18 independent runs that are each 5 days long, and have 6 hours of overlap when the segments are consecutive (this is for the purpose of removing a few of the initial and final hours from the analysis, as these are prone to strange end effects. The `<periods_*>` files are the simplest expression of these time windows. Everything else is related to the stocastic realizations used to create stochasticity in the model, and the core model is capable of creating these inputs (although you may wish to supply them instead of using the native functions for generating them). They are saved for future reference and so that future simulations can use the same set of realizations.

The outputs/ folder is where model outputs are saved. Each simulation generates a number of files (one set for each time period indicated by the periods_* files in the inputs/5d_6o_keyDays2/ file, or file you specify), which are saved in a folder inside of the outputs/ folder. These folders can be quite large, so if you are running this on Stanford's Sherlock, recommended to move these to GROUP-HOME for long term storage and later analysis.

The code/ folder is where the action is.
- Main model: ercot_stoch.jl and ercot_stoch_reliability.jl. These are quite similar; the latter is used to handle runs where DR reliability is uncertain. Future work could combine these rather easily, it just hasn't been done. 
- inputs_ercot.csv: this contains the inputs used by ercot_stoch.jl and ercot_stoch_reliability.jl. Each unique set of parameters is its own column, so you will add a new column when you want to run a new simulation. Those parameters will be copied over into the outputs folder for that simulation upon running, for posterity. 
- A .sbatch folder for submitting the model to slurm on stanford's Sherlock cluster.

code/R_Scripts contains the R scripts used to do post-processing. 
After each successful model run has completed (e.g. all time periods have completed) and been moved to GROUP-HOME, I recommend using analysis_R.sbatch to submit `<short_submission_script.R>`, which will run post-processing scripts `<visualize_DR_use.R>` and `<combine_summary_files.R>`. You will want to update `<short_submission_script.R>` with the runs that need to be handled. Any brand-new runs need to pass through `<visualize_DR_use.R>`, which combines stats from the multiple time periods together and creates some summary stats for the simulation. Pass to  `<combine_summary_files.R>` all of the runs that you want to compare. Some of the scripts in `<code/R_Scripts/plotting_and_inspection>` are built to handle the output from `<combine_summary_files.R>`.

