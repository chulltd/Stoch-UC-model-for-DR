# combine_summary_files.csv
# combines summary stats from multiple types of simulations together for comparison and analysis
# saves as combined_summary.csv in outputFol

# load model data
library(plyr) #for rbind.fill
library(tidyverse)
library(data.table)
source("~/dr_stoch_uc/code/R_Scripts/getModelParams.R")


# iterate through all summary files and combine them ####
combineSummaryFiles = function(runIDs, runDates,base_fol = "~/dr_stoch_uc/" ,outputFol = NULL){
  # use library(plyr) #for rbind.fill
    if(is.null(outputFol)){
      output_fol_base  = "/home/groups/weyant/plevi_outputs/"#slowgas/"
    } else {
      print("using provided output folder")
      output_fol_base  = outputFol
    }
    input_fol = "inputs/"
    inputs_file = paste0(base_fol,"/code/inputs_ercot.csv")

  # load summary_stats created by visualize_DR_use/combineRunResults for each run
  # combine this with inputs from the model-generated copy of inputs
  # put all runs in the same dataframe
  for(i in 1:length(runIDs)){
    print(runIDs[i])
    # load summary file
    summaryFilePath = paste0(runIDs[i],"_",runDates[i],"/summary_stats",runIDs[i],".csv")
    if(file.exists(paste0(output_fol_base,summaryFilePath))){
      summaryfile = read_csv(paste0(output_fol_base,summaryFilePath))
    } else {
      stop(paste0("File ",runIDs[i],"_",runDates[i]," could not be found in", output_fol_base))
    }
    
    # clean summary file
     summary2 = spread(summaryfile,key = output_type, value = output_value) # should make a 1-row dataframe
 
    # combine params, summary file, append to existing outputs
    if(i==1){
      # create outputs matrix
      alloutputs = cbind(runIDs[i],summary2)
      names(alloutputs) = c("runID",names(summary2))
    } else {
      # bind a new row
      newoutputs = cbind(runIDs[i],summary2) 
      names(newoutputs) = c("runID",names(summary2))
      alloutputs = plyr::rbind.fill(alloutputs,newoutputs)
       
    }
    
  } #end iteration over runs
  
  ## calculate new outputs if noDR run present##
    # make TYPE column for easier plotting. grep the first number or _ in runID
    alloutputs$type = substr(alloutputs$runID,1,regexpr("[0-9_]",alloutputs$runID)-1)
    # expected MWh shed
    alloutputs$`Expected MWh Shed by DR` = as.numeric(alloutputs$`expected DR prod costs`)/as.numeric(alloutputs$`dr_varcost`)
    # expected hours DR is on
    alloutputs$`Expected hours DR is committed` = as.numeric(alloutputs$`Hours DR is on`)/as.numeric(alloutputs$nrandp)
  
  ## For outputs that require reference to noDR
    # repair NA `expected Total costs` columns
    repairsel = which(is.na(alloutputs$`expected Total costs`))
    alloutputs$`expected Total costs` = rowSums(cbind(as.numeric(alloutputs$`all costs slow gens`), 
                                            as.numeric(alloutputs$`expected fast all costs`), 
                                            as.numeric(alloutputs$`expected DR all costs`)), na.rm = T)
    
    # identify noDR row
    noDR_row = which(str_detect(alloutputs$runID,"noDR")) # if there are multiple noDR rows, use first one 
    #TODO: change this to use the one with the most recent date, or just get rid of the old noDR folder!
    if(length(noDR_row) > 0){ 
      noDR_row = noDR_row[1]
      # total cost savings rel to noDR, absolute and as pct
      alloutputs$`expected Total costs` = as.numeric(alloutputs$`expected Total costs`)
      alloutputs$`Expected cost reduction from DR` = alloutputs$`expected Total costs`[noDR_row] - alloutputs$`expected Total costs`
      alloutputs$`Expected cost reduction from DR, frac` = 
        (alloutputs$`expected Total costs`[noDR_row] - alloutputs$`expected Total costs`)/alloutputs$`expected Total costs`[noDR_row]
      
      # cost reduction per MWh shed
        # mwh shed is DR prod cost / dr_varcost
      alloutputs$`Expected cost reduction per MWh shed` = alloutputs$`Expected cost reduction from DR` / alloutputs$`Expected MWh Shed by DR`
      
      # CO2 reduction rel to noDR
      alloutputs$`Total CO2 emissions` = as.numeric(alloutputs$`expected slow CO2 emissions`) + 
        as.numeric(alloutputs$`expected fast CO2 emissions`) + as.numeric(alloutputs$`expected DR CO2 emissions`)
      # alloutputs$`Total CO2 emissions`[fixsel] = alloutputs$`Total CO2 emissions`[fixsel]/5
      alloutputs$`Expected CO2 reduction from DR` = alloutputs$`Total CO2 emissions`[noDR_row] - alloutputs$`Total CO2 emissions`
    }
    
  # save
  write_csv(alloutputs,paste0(output_fol_base,"combined_summary.csv")) 
}