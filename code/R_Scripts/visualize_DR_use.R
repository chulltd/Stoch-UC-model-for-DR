# visualize_DR_use.R
# called by short_submission_script.R
# this function wraps around combine_run_results.R and adds 
# the ability to iterate over multiple runs, and generate selected plots
# using plotDRUse()
# Patricia Levi, March 2019

# load model data
library(plyr)
library(tidyverse)
library(viridis)
library(data.table)
options(warn=1) # print warnings as they occur

## FILE STRUCTURE ##
base_fol = "~/dr_stoch_uc/"
output_fol_base  = "/home/groups/weyant/plevi_outputs/"#slowgas/"
input_fol = "inputs/"

# get all run parameters
inputs_file = paste0(base_fol,"/code/inputs_ercot.csv")
allinputs = read_csv(inputs_file)

### PARAMS ####----##

## run options
inputfolID = "5d_6o_keyDays2" # for plotDR - need to fix to read in dynamically.
summary_combine = T # needed to create prod.csv
plotDR = F
genbreakdown_only = F # this is done in summary_combine
rampdata_df = F
loadOverrideOption = F# should prod be re-calculated?
##----##----##----##

instance_in_fol = paste0(base_fol,input_fol,inputfolID,"/") 
default_in_fol = paste0(base_fol,input_fol,"ercot_default/")

source(paste0(base_fol,"code/R_Scripts/mergeTimeseriesData.R")) # contains loadTimeseriesData
source(paste0(base_fol,"code/R_Scripts/consolidatedAnalysisFns.R")) # contains plotting functions
source(paste0(base_fol,"code/R_Scripts/combine_run_results.R")) # contains combineRunResults()

# combine run results
if(summary_combine){
  print("starting combineRunResults")
  options(readr.num_columns = 0) # turn off read_csv messages
  for(r in 1:length(runIDs)){
    print(runIDs[r])
    combineRunResults(runIDs[r],runDates[r],graphs=F,load_override = loadOverrideOption,
                      base_fol = base_fol, output_fol_base = output_fol_base)
    warnings()
  }
}

# plot DR use
if(plotDR){
  print("starting plotDRUse")
  for(r in 1:length(runIDs)){
    params = allinputs[,c("input_name",runIDs[r])]
    params = spread(params, key = input_name, value = runIDs[r])
    overlaplength = as.numeric(params$overlapLength)
    
    outputID = paste0(runIDs[r],"_",runDates[r])
    output_fol = paste0(output_fol_base,outputID,"/")
    output_fol = paste0(output_fol_base,outputID,"/")
    allcomt = loadTimeseriesData(output_fol,"u_commitment",overlaplength,2, probabilities=F,instance_in_fol,params$nrandp,dist_ID = params$stochID,endtrim=6)
    drcomt = filter(allcomt,str_detect(GEN_IND,"DR-"))
    rm(allcomt)
    # iterate over function
    # plot dr commitment and demand
  
    plotDRUse(runIDs[r],runDates[r], drcommit = drcomt, 
              inputfolID=inputfolID,outputfolID = outputID,
              period = "p2_1020_1140")
  
  } #end for loop
}

# only generate genbreakdown plot - done with in combineRunResults too
if(genbreakdown_only){
  print("starting genbreakdown")
  for(r in 1:length(runIDs)){
    print(runIDs[r])
    outputID = paste0(runIDs[r],"_",runDates[r])
    output_fol = paste0(output_fol_base,outputID,"/")
    # load gendat
    params = allinputs[,c("input_name",runID)]
    params = spread(params, key = input_name, value = runID)
    gendat = read_csv(paste0(default_in_fol,params$genFile))
    # load prod
    print("Loading prod.csv")
    prod = read_csv(file = paste0(output_fol,"prod.csv"))
    prod$prob = 1/25
    # merge
    prod2 = prod %>%
      merge(gendat[,c("Capacity","PMin","plantUnique","VCost","Fuel")], by.x = "GEN_IND", by.y = "plantUnique") %>%
      filter(MWout > 0)
  
    fuelBreakdown(prod2,paste0(output_fol_base,"plots/"),runIDs[r])
  }
}

# create dataframe of ramping data
if(rampdata_df){
  print("starting rampdata")
  for(r in 1:length(runIDs)){
    print(runIDs[r])
    outputID = paste0(runIDs[r],"_",runDates[r])
    output_fol = paste0(output_fol_base,outputID,"/")

    params = allinputs[,c("input_name",runID)]
    params = spread(params, key = input_name, value = runID)
    gendat = read_csv(paste0(default_in_fol,params$genFile))
    # load prod
    print("Loading prod.csv")
    prod = read_csv(file = paste0(output_fol,"prod.csv"))
    prod$prob = 1/25
    # merge
    prod2 = prod %>%
      merge(gendat[,c("Capacity","PMin","plantUnique","VCost","Fuel")], by.x = "GEN_IND", by.y = "plantUnique") %>%
      filter(MWout > 0)
  
    
    if(r == 1){
      xx = rampInfo(prod2,runIDs[r])
    } else {
      xx = bind_rows(xx,rampInfo(prod2,runIDs[r]))
    }
  }
  xx=arrange(xx,REgen,speed,runName)
  write_csv(xx,path = paste0(output_fol_base,"Ramp_data3.csv"))
}
