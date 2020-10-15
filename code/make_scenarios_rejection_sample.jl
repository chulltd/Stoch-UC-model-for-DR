#= make_scenarios_rejection_sample.jl
make timeseries of DR performance with a mean performace near 100%
Give a set of outcomes that each have an associated probability
And information on how often to resample from those outcomes

inputs:
n of total timesteps
prob distribution of performance and outcomes, vdr, p (original)
number of timesteps in which DR performance is constant
should scenarios be randomly selected
how many scenarios are selected?
threshold for rejection

outputs:
vdr[t,o]
p[o]
=#
using StatsBase
function make_scenarios(n_timesteps,v_og,p_og,int_length; randsel = true, nrand = 5, thresh = 0.005)
    # determine total number of possible scenarios
    Tp = convert(Int64,floor(n_timesteps/int_length)) # number of time blocks
    n_omega = length(p_og) # number of possilbe outcomes
    n_new_scenarios = convert(Int64,n_omega^Tp)


    # make vdr placeholder and all_s
    vdr = fill(0.0,(n_timesteps,nrand))
    p = fill(0.0,(nrand))
    all_s = collect(1:n_new_scenarios)

    # rejection sample
    i=1;
    n_sampled = 0
    while i<n_new_scenarios && n_sampled < nrand
        # draw a single sample
        s = sample(all_s,1)
        println("sampled ",s)

        # make vdr data for that sample
        s_vdr = fill(0.0,(n_timesteps))
        s_p = fill(0.0,(n_timesteps))
        for j in 1:Tp #row chunk
            # identify which rows belong to this time period
            if j == Tp
                last_period = n_timesteps
            else
                last_period = int_length*j #t_firsts[i+1]-1
            end
            rows = (int_length*(j-1) + 1):last_period

            # sample correct performance for that time period
            # imagine all possible combos are listed out in an array that is Tp x n_new_scenarios
            ind = mod(fld(s[1]-1,n_omega^(Tp-j)),n_omega)+1
                # fld: largest integer <= x/y
                # n_omega^(Tp-j) is the number of row-wise 'blocks' of the same response in our imagined array
                #           on the last block, there is just one block (j=Tp, this = 1)
                #           on the first block,   (j=1, this = n_omega^(Tp-1), e.g. n of blocks if every n_omega blocks were grouped)
                # divide sample number by above;
                # find remainer of that with number of possible responses
                # add 1 since above is 0-indexed
            s_vdr[rows] = v_og[ind]
            s_p[rows] = p_og[ind]
        end

        # assess if s_vdr is ok
        if abs(1-mean(s_vdr,weights(s_p))) < thresh #mean is weighted by probability
            # add to vdr and p
            vdr[:,n_sampled+1] = s_vdr
            p[n_sampled+1] = prod(s_p)
            # update n_sampled
            n_sampled = n_sampled+1
            println("added sample ",s)
        end

        # remove from possible scenarios to sample
        deleteat!(all_s,find(all_s .== s))

        i=i+1;
    end
    return(vdr,p)
end
