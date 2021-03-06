# combine_run_results.R
# reads in output from one simulation (a set of periods with same parameters) 
# from ercot_stoch.jl model (via loadTimeseriesData() in mergeTimeseriesData.R)
# extracts key outputs, makes a few graphs, and saves key numbers in a csv
# Also saves csvs with combined output from all time windows modeled in this simulation.
# also indicates if any runs were missing (and fails if so), saving a csv of that info
# march 2019
# Patricia levi

# load model data
library(plyr)
library(tidyverse)
library(viridis)
library(data.table)

options(warn=1) # print warnings as they occur

## FILE STRUCTURE ##
baseFol = "~/dr_stoch_uc/"
outputFolBase = "/home/groups/weyant/plevi_outputs/"#slowgas/"
inputFol = "inputs/"


## source files ##
source(paste0(baseFol,"/code/R_Scripts/mergeTimeseriesData.R")) # contains loadTimeseriesData
source(paste0(baseFol,"/code/R_Scripts/consolidatedAnalysisFns.R")) # genBreakdown()
source(paste0(baseFol,"/code/R_Scripts/getModelParams.R"))
source(paste0(baseFol,"/code/R_Scripts/getProbs.R"))


### PARAMS for testing ####----##
# inputfolID = "5d_keyDays"
# runID = "avail2_keyDays" #"hour1" #"avail2"
# runDate = "2019-03-17" #this might differ across runs! need to consolidate
# overlaplength = 24
# nperiods = 22
# graphs = FALSE
##----##----##----##

combineRunResults <- function(runID, runDate, graphs = T, 
                              base_fol = baseFol, 
                              output_fol_base = outputFolBase ,
                              input_fol = inputFol,
                              SHRLOK = SHRLK, load_override = F, endtrim = NULL){  
  
  outputID = paste0(runID,"_",runDate)
  output_fol = paste0(output_fol_base,outputID,"/")
  default_in_fol = paste0(base_fol,input_fol,"ercot_default/")
  
  params = getModelParam(run_date = runDate,run_name = runID, output_fol_base) 
  params$nrandp = as.numeric(params$nrandp)
  overlaplength = as.numeric(params$overlapLength)
  if(is.null(endtrim)){
    endtrim = overlaplength/2
    print(paste("endtrim set to", endtrim))
  }
  
  print(paste("overlap length is",overlaplength,"and number of scenarios is",params$nrandp))
  
  inputfolID = params$timeseriesID
  instance_in_fol = paste0(base_fol,input_fol,inputfolID,"/") 
  
  # load gendat - based on name in inputs_file
  gendat = read_csv(paste0(default_in_fol,params$genFile))
  # set VCost of DR to match inputs_file
  if(as.logical(params$dr_override)){
    drind = which(str_detect(gendat$plantUnique,"DR-"))
    gendat$VCost[drind] = as.numeric(params$dr_varcost)
    print(paste0("Reset VCost for ",length(drind)," DR plants"))
  }
  
  #---------------------------------
  ### load max slow committed capacity #####
  
  # load slow commitment 
  slowcomt = loadTimeseriesData(output_fol,"slow_commitment", overlaplength,1, endtrim=endtrim)
  
  # ID missing periods ####
  theseperiods = unique(slowcomt$nperiod)
  print("completed periods:")
  print(theseperiods)
  print(paste("number of completed periods is", length(theseperiods)))
  
  if(!file.exists(paste0(instance_in_fol,"orderoffiles.csv"))){
    arrayind = data.frame(filename = list.files(path = instance_in_fol, pattern = "periods_"))
    arrayind$arraynum = 0:(length(arrayind$filename)-1)
    periodinfo = t(array(unlist(strsplit(as.character(arrayind$filename),"_")),dim=c(4,nrow(arrayind))))
    arrayind$periodnum = periodinfo[,2]
    write_csv(arrayind,paste0(instance_in_fol,"orderoffiles.csv"))
  }
  arrayind = read_csv(paste0(instance_in_fol,"orderoffiles.csv"))
  
  full = as.numeric(arrayind$periodnum)
  missingnum = full[which(!(full %in% theseperiods))]
  print("missing periods:")
  print(missingnum)
  
  whichmissing = arrayind$periodnum %in% missingnum
  outarray = matrix(arrayind$arraynum[whichmissing],nrow=1)
  if(sum(whichmissing)>0){
    print("missing array numbers:")
    print(outarray)
    write.csv(outarray,paste0(output_fol,"missing_periods_arraynum_slowcommt.csv"),row.names = F)
    stop("missing periods!")
  }
  #
    
  
  # initialize summary output file
  write("output_type, output_value",file = paste0(output_fol,"summary_stats",runID,".csv"))
  # write file name and date
  write(paste0("folder name,",outputID,"\n "),
        file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)  
  
  # add params
  print("writing params")
  # need to make params vertical
  write.table(gather(params, key = "input_name", value = "input_value"), 
              sep=",", row.names = FALSE, col.names = FALSE, quote = FALSE,
            file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)
  
  # match comt decision with capacity
  # gather gen names
  # merge with gendat
  cmtcap = slowcomt %>%
    gather(key = "generator", value = "cmt", -t) %>%
    merge(gendat[,c("Capacity","PMin","plantUnique","VCost")], by.x = "generator", by.y = "plantUnique") %>%
    mutate(capComt = cmt*Capacity) %>%
    group_by(t) %>%
    summarise(allcmtcap = sum(capComt))
  write.csv(cmtcap,paste0(output_fol,"slow_committed_capactity.csv"),row.names = F)
  
  if(graphs){
    ggplot(cmtcap,aes(x=allcmtcap/1000)) + geom_histogram() +
    ggtitle("Distribution of slow capacity committed") + labs(x = "GW committed") +
    ggsave(paste0(output_fol,"hist_slow_commit_",runID,".png"),width = 4, height = 5)
  }
  xx =summary(cmtcap$allcmtcap)
  write(paste0("Min slow commit GW incl slow DR,",xx[[1]],"\n ","Max slow commit GW incl slow DR,",xx[[6]],"\n"),
        file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)  
  
  rm(slowcomt) #for memory management
  #---------------------------------
  ### Load production data ####
  
  
  # load production, startup data
  if(!file.exists(paste0(output_fol,"prod.csv")) | !file.exists(paste0(output_fol,"slow_gens.csv")) | load_override){
    print("Loading fast production data")
    fastprod = loadTimeseriesData(output_fol, "fast_production", overlaplength,2,instance_in_fol,params$nrandp,
                                  dist_ID = params$stochID, probabilities = F, endtrim = endtrim)
    print("Loading slow production data")
    slowprod = loadTimeseriesData(output_fol, "slow_production", overlaplength,2,instance_in_fol,params$nrandp,
                                  dist_ID = params$stochID, probabilities = F, endtrim = endtrim)
    slowprod$speed = "slow"
    fastprod$speed = "fast"
    
    # ID slow gens - a simple vector
    slowgens = unique(slowprod$GEN_IND)
    write.csv(slowgens, paste0(output_fol,"slow_gens.csv"))
    
    prod = rbind(slowprod, fastprod)
    names(prod)[names(prod) == 'value'] <- 'MWout'
    rm(fastprod, slowprod)
    # prod header: "","GEN_IND","t","nperiod","scenario","MWout","speed","prob"
    
    allprobs = getProbs(params, instance_in_fol, length(unique(prod$scenario)))
    prod = merge(as.data.table(prod), as.data.table(allprobs), by.x = c("scenario","nperiod"), by.y = c("scenarionum","periodnum"), all.x=T)
    
    write.csv(prod, paste0(output_fol,"prod.csv"))
  } else {
    print("Loading prod.csv")
    prod = read_csv(file = paste0(output_fol,"prod.csv"))
    prod = select(prod, -prob) #previous calculations mis-calculated prod - recalculate it
    print("starting getProbs")
    allprobs = getProbs(params, instance_in_fol, length(unique(prod$scenario)))
    print("finishing getProbs")
    print(allprobs)
    prod = merge(as.data.table(prod), as.data.table(allprobs), by.x = c("scenario","nperiod"), by.y = c("scenarionum","periodnum"), all.x=T)
    slowgens = read_csv(file = paste0(output_fol,"slow_gens.csv"))
    slowgens = slowgens$x
    print(head(slowgens))
  }
  
  if(!("PMin" %in% colnames(prod))){
    prod = prod %>%
      merge(gendat[,c("Capacity","PMin","plantUnique","VCost","Fuel","PLC2ERTA")], by.x = "GEN_IND", by.y = "plantUnique") 
  }
  
  
  ## Find ramp rates of system ####
  # differentiate by slow ramp and total ramp
  prodramp= prod %>%
    group_by(scenario,speed,t) %>%
    summarise(MWtot = sum(MWout)) %>%
    group_by(scenario,speed) %>%
    mutate(ramp = MWtot - lag(MWtot, default=0))
  
  prodrampsummary_all = prodramp%>%
    group_by(speed) %>%
    summarise(maxramp = max(ramp),
              minramp = min(ramp))
  
  # remove DR from prod & find ramp
  prodRest = prod %>%
    filter(GEN_IND != "DR-1")
  
  prodramp= prodRest %>%
    group_by(scenario,speed,t) %>%
    summarise(MWtot = sum(MWout)) %>%
    group_by(scenario,speed) %>%
    mutate(ramp = MWtot - lag(MWtot, default=0))
  
  prodrampsummary_allDR = prodramp%>%
    group_by(speed) %>%
    summarise(maxramp = max(ramp),
              minramp = min(ramp))
  prodrampsummary_all
  prodrampsummary_allDR
  write(paste0("ramp max fast,",prodrampsummary_all$maxramp[1],"\n ",
               "ramp max fast DR removed,",prodrampsummary_allDR$maxramp[1],"\n",
               "ramp min fast,",prodrampsummary_all$minramp[1],"\n",
               "ramp min fast DR removed,",prodrampsummary_allDR$minramp[1],"\n",
               "ramp max slow,",prodrampsummary_all$maxramp[2],"\n",
               "ramp max slow DR removed,",prodrampsummary_allDR$maxramp[2],"\n",
               "ramp min slow,",prodrampsummary_all$minramp[2],"\n",
               "ramp min slow DR removed,",prodrampsummary_allDR$minramp[2],"\n"),
        file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)  
  
  # visualize/summarize ramp ####

  # visualize daily max ramp
  prodramp$day = floor(prodramp$t/24)
  prodrampday = prodramp %>%
    group_by(day,scenario) %>%
    summarise(daymaxramp = max(ramp),
              dayminramp = min(ramp))
  #TODO: summarise prodramp by combining speeds first - this currently pits fast and slow against each other
  
  quants = quantile(prodrampday$daymaxramp[prodrampday$daymaxramp >0], probs = c(0.5,0.9,0.95,0.99,0.995,1), na.rm=T)
  write(paste0("ramp 50% nonDR quantile,",quants[1],"\n",
               "ramp 90% nonDR quantile,",quants[2],"\n ",
               "ramp 95% nonDR quantile,",quants[3],"\n",
               "ramp 99% nonDR quantile,",quants[4],"\n",
               "ramp 99.5% nonDR quantile,",quants[5],"\n",
               "ramp 100% nonDR quantile,",quants[6],"\n",
               "ramp stdev,",sd(prodrampday$daymaxramp[prodrampday$daymaxramp >0]),"\n"),
        file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)  
  
  
  #---------------------------------
  ### Find marginal cost statistics, graph ####
  
  ## plot marginal price ##
  prod2 = prod %>%
    filter(MWout > 0) 
  prod_margprice = prod2 %>%
    group_by(t,scenario) %>%
    summarise(margprice = max(VCost),
              marggen = GEN_IND[which.max(VCost)],
              marggencap = Capacity[which.max(VCost)],
              marggenspd = speed[which.max(VCost)])
  
  if(graphs){
  ggplot(prod_margprice, aes(x=t, y = margprice, color = scenario)) + 
    geom_line(aes(color = scenario)) + ggtitle("marginal price across scenarios") +
    scale_color_viridis(discrete=T) + theme_bw() +
    ggsave(filename = paste0(output_fol,"marginal_price_",runID,".png"), width = 7, height = 5)
  ggplot(prod_margprice,aes(x=margprice, fill=scenario)) + geom_histogram() + 
    scale_fill_viridis(discrete=T) + theme_bw() +
    ggsave(filename = paste0(output_fol,"marginal_price_hist_",runID,".png"), width = 7, height = 5)
  }
  mcostsummary = summary(prod_margprice$margprice)
  write(paste0("max marginal price,",mcostsummary[[6]],"\n ",
               "min marginal price,",mcostsummary[[1]],"\n",
               "median marginal price,",mcostsummary[[3]],"\n"),
        file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)  
  
  #---------------------------------
  ## consolidated data of generation source: fuelBreakdown() ####
  if(!file.exists(paste0(output_fol_base,"plots/"))){
    dir.create(paste0(output_fol_base,"plots/"))
  }
  genbreakdown = fuelBreakdown(prod2,paste0(output_fol_base,"plots/"),runID)
  genbreakdown = select(genbreakdown, Fuel, prodFrac)
  genbreakdown$Fuel = paste0("GENFRAC-",genbreakdown$Fuel)
   rm(prod2) # memory mangement
  
  ## write fuelBreakdown to summary stats ##
  write.table(genbreakdown,sep=",", row.names = FALSE, col.names = FALSE, quote = FALSE,
              file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)
  
  #-------------------
  ## startup data / costs ####
  # differentiate by 1st stage (slow) and expected 2nd stage (fast)
  
  speedslow = tibble(GEN_IND = slowgens, speed = "slow")
  
  # load and manipulate all startup data
  if(!file.exists(paste0(output_fol,"fast_startup_all.csv")) | load_override){
    print("Loading startup data")
    allstartup = loadTimeseriesData(output_fol,"v_startup",overlaplength,
                                    2,instance_in_fol,params$nrandp,dist_ID = params$stochID, probabilities = F, endtrim=endtrim)
    allprobs = getProbs(params, instance_in_fol, length(unique(prod$scenario)))
    allstartup = merge(as.data.table(allstartup), as.data.table(allprobs), by.x = c("scenario","nperiod"), by.y = c("scenarionum","periodnum"), all.x=T)
    
    names(allstartup)[names(allstartup) == 'value'] <- 'startup'
  
    write.csv(allstartup, paste0(output_fol,"fast_startup_all.csv"))
  } else {
    print("Loading v_startup_all.csv")
    allstartup = read_csv(file = paste0(output_fol,"fast_startup_all.csv"))
    allstartup = select(allstartup, -prob) #prev methods of calculating prob may have been wrong, recalculate
    print("starting getProbs")
    allprobs = getProbs(params, instance_in_fol, length(unique(prod$scenario)))
    print("finished getProbs")
    allstartup = merge(as.data.table(allstartup), as.data.table(allprobs), by.x = c("scenario","nperiod"), by.y = c("scenarionum","periodnum"), all.x=T)
    
  }
  
   print("merge with gen speed info")
  allstartup = merge(as.data.table(allstartup), as.data.table(speedslow),by = "GEN_IND", all.x=T)
  allstartup$speed[is.na(allstartup$speed)] = "fast"
  fastsel = which(allstartup$speed == "fast")
  
  print("merge with other gen information")
  allstartup = merge(as.data.table(allstartup), as.data.table(gendat[,c("plantUnique","StartCost")]), all.x=T, by.x = "GEN_IND", by.y = "plantUnique")
  
  # calculate expected cost
  # when calculating costs, make sure negative startup is not negative cost
  allstartup$startup[allstartup$startup < 0]=0
  allstartup$expectedcost = 0
  allstartup$expectedcost = allstartup$startup * allstartup$prob * allstartup$StartCost
  
  # sum across scenarios
  startcost = allstartup %>%
    group_by(t, speed) %>%
    summarise(ecost = sum(expectedcost))
  rm(allstartup) #memory management
  
  # plot ##
  startcostplot = startcost %>%
    filter(ecost >0)
  if(graphs){
  # regular plot
  ggplot(startcostplot, aes(x=t, y=ecost, color = speed)) + geom_point() +
    theme_bw() +
    ggsave(filename = paste0(output_fol,"startupcosts_",runID,".png"), width = 7, height = 5)
  
  # cropped reg plot
  ggplot(startcost, aes(x=t, y=ecost, color = speed)) + geom_line() + 
    theme_bw() +
    coord_cartesian(ylim = c(1,5e5))+
    ggsave(filename = paste0(output_fol,"startupcosts_zoom_",runID,".png"), width = 7, height = 5)
  
  # log plot
  ggplot(startcostplot, aes(x=t, y=ecost, color = speed)) + geom_point() +
    scale_y_continuous(trans='log10') +
    coord_cartesian(ylim = c(1,1e7)) +
    theme_bw()+
    ggsave(filename = paste0(output_fol,"startupcosts_log_",runID,".png"), width = 7, height = 5)
  ## end plots ##
  }
  
  # sum across time
  startcosttot = startcost %>%
    group_by(speed) %>%
    summarise(ecost = sum(ecost)) %>%
    spread(key=speed,value=ecost)
  # write to summary stats
  write(paste0("startup costs slow gens,",startcosttot$slow[1],"\n ",
               "expected startup costs fast gens,",startcosttot$fast[1],"\n"),
        file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)  
  
  #-------------------
  ## production costs AND co2 emissions ####
  # differentiate by 1st stage and expected 2nd stage
  
  # prob already loaded and differentiated by speed
  # special case - check DR separately
  prod$speed[str_detect(prod$GEN_IND,"DR-")] = "DR"
  
  # find expected costs, weighted by scenario probability
  prodcost = prod %>%
    mutate(expectedcost = MWout * VCost * prob,
           expectedCO2 = MWout * PLC2ERTA * prob) %>% 
    group_by(speed,t) %>%
    summarise(ecost = sum(expectedcost),
              eco2 = sum(expectedCO2, na.rm = T))
  
  # plot ##
  prodcostplot = prodcost %>%
    filter(ecost >0)
  if(graphs){
  # regular plot
  ggplot(prodcostplot, aes(x=t, y=ecost, color = speed)) + geom_line() +
    theme_bw() +
    ggsave(filename = paste0(output_fol,"productioncosts_",runID,".png"), width = 7, height = 5)
  }
  
  # sum expected costs across time
  prodcosttot = prodcost %>%
    group_by(speed) %>%
    summarise(ecost = sum(ecost),
              co2 = sum(eco2, na.rm = T)) #%>%
    # spread(key=speed,value=ecost)
  slowseltot = which(prodcosttot$speed == "slow")
  fastseltot = which(prodcosttot$speed == "fast")
  DRseltot = which(prodcosttot$speed == "DR")
  # write to summary stats
  write(paste0("expected slow prod costs,",prodcosttot$ecost[slowseltot],"\n ",
               "expected fast prod costs,",prodcosttot$ecost[fastseltot],"\n",
               "expected DR prod costs,",prodcosttot$ecost[DRseltot],"\n",
               "expected slow CO2 emissions,",prodcosttot$co2[slowseltot],"\n ",
               "expected fast CO2 emissions,",prodcosttot$co2[fastseltot],"\n ",
               "expected DR CO2 emissions,",prodcosttot$co2[DRseltot],"\n "),
        file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)  
  
  #-------------------
  ## combined costs ##
  names(prodcostplot) = c("speed","t","prod","co2")
  names(startcostplot) = c("t","speed","startup")
  allcosts = merge(prodcostplot,startcostplot, by = c("t","speed"), all=T)
  allcosts = gather(allcosts, key = "cost_type", value = "cost", prod, startup)
  
  allcosts_byspeed = allcosts %>%
    group_by(cost_type) 
  
  ## plot
  if(graphs){
  ggplot(allcosts, aes(x=t,y=cost,color=speed)) + geom_line() +
    facet_wrap(~cost_type, nrow=2, scales = "fixed")+
    theme_bw() +
    ggsave(filename = paste0(output_fol,"allcosts_",runID,".png"), width = 10, height = 8)
  }
  # sum across time
  allcosttot = allcosts %>%
    group_by(speed) %>%
    summarise(ecost = sum(cost,na.rm=T)) %>%
    spread(key=speed,value=ecost)
  
  # count hours DR is on
  dron = prod$MWout > 1e-2 & prod$speed =="DR"
  drsome = prod$MWout > 10 & prod$speed =="DR"
  drpart = prod$MWout > 500 & prod$speed =="DR"
  drfull = prod$MWout > 999 & prod$speed =="DR"
    
  # write to summary stats
  write(paste0("expected slow all costs,",allcosttot$slow[1],"\n",
               "expected fast all costs,",allcosttot$fast[1],"\n",
               "expected DR all costs,",allcosttot$DR[1],"\n",
               "expected Total costs,",sum(allcosttot$DR[1] + allcosttot$fast[1] +allcosttot$slow[1],na.rm=T),"\n",
               "Hours DR is on,", sum(dron),"\n",
               "Hours DR is >1% on,",sum(drsome),"\n",
               "Hours DR is >50% on,",sum(drpart),"\n",
              "Hours DR is >99.9% on,",sum(drfull),"\n",
              "total hours in simulation,",length(unique(allcosts$t))),
        file = paste0(output_fol,"summary_stats",runID,".csv"),append=T)
  
  rm(allcosts,prodcost) # memory mangement
  
}