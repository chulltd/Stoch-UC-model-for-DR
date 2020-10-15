#getProbs.R
# Short function to return probabilities
# of each run for each period
# to be called by combineRunResults()
#Sept 2020 Patricia Levi

library(tidyverse)

getProbs = function(params,inputsfol,nscenarios){
  # does this run have DR randomness in addition to demand randomness?
  demand_files = list.files(path = inputsfol, pattern = paste0("demandScenarios_prob_",params$stochID))
  
  if(is.null(params$DRrand_ID) | !params$DRrand_ID){ # no DR randomness scenarios
    # return(1/nscenarios) #TODO fix this later to actually read in from demandScenarios_prob
    prob_filename = paste0("demandScenarios_prob_",params$stochID)
    drrand = FALSE
  } else {
    prob_filename = paste0("pro_",params$DRrand_ID) # has the probability of the combined DR-demand realizations
    drrand = TRUE
  }
  
  prob_files = list.files(path = inputsfol, pattern = prob_filename)
  #make empty array
  # colnames; periodnum, scenarionum, prob
  for(i in 1:length(prob_files)){
    #load file
    probs = read_csv(paste0(inputsfol,prob_files[i]))
  
    # id period num
    parts = str_split(prob_files[i],"_|\\.")
    p = parts[[1]][length(parts[[1]])-3]
    p = as.numeric(substr(p,2,100))
    # print(paste("period number", p))
    if(drrand){
      # pivot_longer so that scenarionum is a column - only needed for pro_
      probs = pivot_longer(probs, cols = everything(),names_to = "scenarionum", values_to = "prob")
      probs$scenarionum =paste0("o",(substr(probs$scenarionum, 2,100)))
      # # A tibble: 50 x 2
      #  scenarionum     prob
      #  <chr>    <dbl>
      # 1 x1        0.04
      # 2 x2        0   
      # 3 x3        0.04
      # 4 x4        0   
      # 5 x5        0.04
      # 6 x6        0   
      # 7 x7        0.04
      # ...
    } else{
      #just add a scenario number column
      probs$scenarionum = 1:nrow(probs)
      probs$scenarionum = paste0("o",probs$scenarionum)
      #rename V1 -> p 
      probs = rename(probs, prob = V1)
      # A tibble: 5 x 2
      #       prob scenarionum
      #    <dbl>       <int>
      # 1   0.2           1
      # 2   0.2           2
      # 3   0.2           3
      # 4   0.2           4
      # 5   0.2           5
    }
    probs$periodnum = p
    # append to array
    if(i == 1){
      allprobs = probs
    } else {
      allprobs = rbind(allprobs, probs)
    }
  }
  #return array
  return(allprobs)
  
}