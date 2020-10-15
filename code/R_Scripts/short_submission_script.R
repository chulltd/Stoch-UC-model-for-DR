# short submission script for post-processing output
# Output should first be moved to /groups/weyant/ to preserve memory space
# as this operation increases the memory usage for each run
# analysis_R.sbatch should be used to submit this to slurm

## --------------------------------------------------
## Which runs need to have their outputs combined?###
## --------------------------------------------------

# xx = list.files(path = "/home/groups/weyant/plevi_outputs/", pattern = glob2rx("dur*"))
# runIDs33 = substr(xx, 1, nchar(xx)-11)
# runDates33 = substr(xx, nchar(xx)-9,100)
# 
# xx = list.files(path = "/home/groups/weyant/plevi_outputs/slowgas/", pattern = glob2rx("*_o25_*keyDays2*"))
# runIDs34 = substr(xx, 1, nchar(xx)-11)
# runDates34 = substr(xx, nchar(xx)-9,100)
# 
# xx = c("dur4_o25_keyDays2_2020-07-20")
# runIDs35 = substr(xx, 1, nchar(xx)-11)
# runDates35 = substr(xx, nchar(xx)-9,100)
# 
# xx = list.files(path = "/home/groups/weyant/plevi_outputs/", pattern = glob2rx("rand*_o2_*keyDays2*"))
# runIDs36 = substr(xx, 1, nchar(xx)-11)
# runDates36 = substr(xx, nchar(xx)-9,100)
# 
xx = list.files(path = "/home/groups/weyant/plevi_outputs/", pattern = glob2rx("rand*_o1_*keyDays2*"))
runIDs37 = substr(xx, 1, nchar(xx)-11)
runDates37 = substr(xx, nchar(xx)-9,100)

runIDs = c(runIDs37)#, runIDs12)#c(runIDs15,runIDs14,runIDs12)#c(runIDs1,runIDs2)
runDates = c(runDates37)#,runDates12)#c(runDates15,runDates14,runDates12)#c(runDates1, runDates2)


# see visualize_DR_use.R for other params, including TF recalculate prod, and TF make plots
## --------------------------------------------------
## Run visualize DR use.R
source("visualize_DR_use.R")
## --------------------------------------------------

## --------------------------------------------------
### Which runs should be included in the combine_summary.csv file? ####
## --------------------------------------------------

# xx = list.files(path = "/home/groups/weyant/plevi_outputs/", pattern = glob2rx("*_o25*keyDays2*"))
# last_loc = as.vector(regexpr("\\_[^\\_]*$", xx))
# runIDs22 = substr(xx, 1, last_loc - 1)
# runDates22 = substr(xx, last_loc+1,100)
# 
# # runIDs24 = "advNot1_o25_c2_keyDays2"
# # runDates24 = "2019-99-99" # THIS IS A TEST WITH A SMALL PROD
# yy = list.files(path = "/home/groups/weyant/plevi_outputs/", pattern = glob2rx("rand_o25_u*"))
# last_loc = as.vector(regexpr("\\_[^\\_]*$", yy))
# runIDs26 = substr(yy, 1, last_loc - 1)
# runDates26 = substr(yy, last_loc+1,100)
# 
# #HYDRO AS SLOW GENERATOR RUNS
# xx = list.files(path = "/home/groups/weyant/plevi_outputs/slow_hydro/", pattern = glob2rx("*_o25_*keyDays2*"))
# # xx = c("advNot1_o25_keyDays2_2020-02-03", "advNot2_o25_keyDays2_2020-02-03",
# #        "advNot3_o25_keyDays2_2020-02-03", "energy1_o25_keyDays2_2020-02-03",
# #        "energy2_o25_keyDays2_2020-02-03", "energy3_o25_keyDays2_2020-02-03",
# #        "noDR_o25_keyDays2_2020-02-03")
# runIDs27 = substr(xx, 1, nchar(xx)-11)
# runDates27 = substr(xx, nchar(xx)-9,100)
# 
# xx = list.files(path = "/home/groups/weyant/plevi_outputs/slowgas/", pattern = glob2rx("*_o2*keyDays2*"))
# runIDs34 = substr(xx, 1, nchar(xx)-11)
# runDates34 = substr(xx, nchar(xx)-9,100)

xx = list.files(path = "/home/groups/weyant/plevi_outputs/", pattern = glob2rx("*_o2*keyDays2*"))
last_loc = as.vector(regexpr("\\_[^\\_]*$", xx))
runIDs35 = substr(xx, 1, last_loc - 1)
runDates35 = substr(xx, last_loc+1,100)


runIDs = c(runIDs35)#, runIDs12)#c(runIDs15,runIDs14,runIDs12)#c(runIDs1,runIDs2)
runDates = c(runDates35)#,runDates12)#c(runDates15,runDates14,runDates12)#c(runDates1, runDates2)

## --------------------------------------------------
## Run combine summary files
source("combine_summary_files.R")
combineSummaryFiles(runIDs, runDates)