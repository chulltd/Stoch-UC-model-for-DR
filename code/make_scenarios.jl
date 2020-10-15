#=make_scenarios.jl
inputs:
number of timesteps in simulation
value options
probabilities for each value
interval length
TF should we pick a subselection of the scenarios
how many scenarios if so

outputs:
vdr[t,o]
p[o]
this is to make the performance of DR in different
time periods independent.
=#

using StatsBase
function make_scenarios(n_timesteps,v_og,p_og,int_length; randsel = true, nrand = 200)

    Tp = convert(Int64,floor(n_timesteps/int_length))
    n_omega = length(p_og)
    n_new_scenarios = convert(Int64,n_omega^Tp)

    if randsel & (nrand < n_new_scenarios)
        s = sample(1:n_new_scenarios,nrand,replace=false)
    else
        s = 1:n_new_scenarios
    end

    #iterate through rows
    prob_array2 = Array{Float64}(length(s),Tp)
    for i in 1:length(s) #row
        for j in 1:Tp #col
            ind = mod(fld(s[i]-1,n_omega^(Tp-j)),n_omega)+1
            prob_array2[i,j] = p_og[ind]
        end
    end

    # can use prod() to get row-wise products.
    ptemp = prod(prob_array2,2)
    p = ptemp/sum(ptemp)
    # p = round.(p, 10)

    vdr = fill(0.0,(n_timesteps,length(s)))
    for j in 1:length(s) #cols
        for i in 1:Tp #row chunk
            # identify which rows belong to this time period
            if i == Tp
                last_period = n_timesteps
            else
                last_period = int_length*i #t_firsts[i+1]-1
            end
            rows = (int_length*(i-1) + 1):last_period

            ind = mod(fld(s[j]-1,n_omega^(Tp-i)),n_omega)+1
            println(ind)
            vdr[rows,j] = v_og[ind]
        end
    end

    return(vdr,p)
end
