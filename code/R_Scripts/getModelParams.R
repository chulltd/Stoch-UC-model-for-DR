# return model params
# this file containts two versions of getModelParam/s
# one (Params) uses a user-maintained file of params, the other (Param)
# uses outputs saved as a mirror of the inputs for each period run
# the latter is the preferred option.
# Jan 2020 Patricia Levi

#  fn inputs: date, model run. fn outputs: tibble of model params

library(tidyverse)
library(lubridate)


getModelParam = function(run_date,run_name,alloutput_fol){
  runID = paste(run_name, run_date, sep="_")
  output_fol = paste(alloutput_fol, runID,"/", sep="")
  
  # identify all relevant input files
  inputfilenames = list.files(path = output_fol,pattern = "inputfile*")
  
  # load all input files - last 5 rows can be discarded
  for(i in 1:length(inputfilenames)){
    inputs = read_csv(paste0(output_fol,inputfilenames[i]))
    # trim off useless third column
    inputs = inputs[,1:2]
    params = spread(inputs, key = input_name, value = names(inputs)[2]) # when two runs are combined: always the second column name
    # make a container for input files
    if(i==1){
      allinputs = as.data.frame(matrix(nrow = 1,ncol = ncol(params),
                                              dimnames=list(c(),names(params[,1:(ncol(params))]))))
      allinputs[i,] = params
    } else {
      allinputs = rbind.fill(allinputs,params)
    }
    
  }
  
  # inspect allinputs for anomalies
  # check the following inputs for sameness: 1:14,17,18
  for(j in c(1:14,17,18)){
    inputname = inputs$input_name[j]
    nunique = length(unique(allinputs[,inputname]))
     if(nunique > 1){
      stop("There is more than 1 given ",inputname," for run ",runID)
    }
  }
  # save a single row and return
  # make empty tibble for returned values
  paramReturn = as.data.frame(matrix(nrow = 1,ncol = ncol(allinputs),
                                     dimnames=list(c(),names(allinputs))))
  paramReturn = allinputs[1,]
  # MIPGapParam matters - return average MIPGap
  paramReturn$MIPGapParam = mean(as.numeric(allinputs$MIPGapParam))
  # other params - return minimum value
  paramReturn$MethodParam = min(as.numeric(allinputs$MethodParam))
  paramReturn$MIPFocusParam = min(as.numeric(allinputs$MIPFocusParam))
  paramReturn$NodefileStartParam= min(as.numeric(allinputs$NodefileStartParam))
  
  # return params
  return(paramReturn)
}


# uses outputs stored in a user-maintained file. No longer used
getModelParams = function(run_dates,run_names,randTF,data_loc = "/home/users/pjlevi/dr_stoch_uc/julia_ver/outputs/model_param_lookup.csv"){
  paramLookup = read_csv(data_loc)
  paramLookup$`first date` = mdy(paramLookup$`first date`)
  paramLookup$`last date` = mdy(paramLookup$`last date` )
  # make empty tibble for returned values
  paramReturn = as.data.frame(matrix(nrow = length(run_dates),ncol = 6,
                                     dimnames=list(c(),names(paramLookup[(ncol(paramLookup)-5):ncol(paramLookup)]))))
  
  # parse run_dates to DATE type -- must deal with -vX at the end of some
  run_dates = ymd(substr(run_dates,1,10)) # assume in format like "2019-01-01"
  
  for(i in 1:length(run_dates)){
    # ID which row of paramLookup is correct
    if(!is.na(randTF[i]) & randTF[i]){
      # subsel for RAND part of paramLookup
      randSel = which(paramLookup$randTF)
    } else {
      #subsel for other part of paramLookup
      randSel = which(!paramLookup$randTF)
    }
    paramRow = randSel[which(paramLookup$`first date`[randSel] <= run_dates[i] & paramLookup$`last date`[randSel] >= run_dates[i])] 
    
    if(length(paramRow) == 0){
      print(paramLookup)
      print("is run_date[i] a date?")
      print(as.character(is.Date(run_dates[i])))
      stop(paste0("No date matches for run_date ",i,", which is ",run_dates[i]))
    } else if(length(paramRow)>1){ 
      warning(paste0("Multiple date matches for run_date ",i,", which is ",run_dates[i],". Using first one"))
      paramRow = paramRow[1]
    }
    # put that row into paramReturn
    paramReturn[i,] = paramLookup[paramRow,(ncol(paramLookup)-5):ncol(paramLookup)]
  }
  return(paramReturn)
}

