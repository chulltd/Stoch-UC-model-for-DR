# short helper fn for ercot_stoch that formats the name appropriately

function writecsvmulti(output,folder,name,multitf,periodID)
    if multitf
        CSV.write(string(folder,name,"_",periodID,".csv"), output)
    else
        CSV.write(string(folder,name,".csv"), output)
    end
end
