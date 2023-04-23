using Pkg
Pkg.activate(@__DIR__)

using Graphs
using GraphPlot
using DataFrames, Random, Distributions, ProgressBars, Chain

# functions ##########################
begin
    function river_and_dams(dataframe)
        df = filter(:type_source => x -> (x=="river")||(x=="dam"), dataframe) # keep only type of interest
        df = innerjoin(df[:, Not([:magnitude, :time])], # join the PRESENT source with PAST target - allow to inherit magnitude paramters efficiently
                       df[:, [:target, :magnitude, :time]], 
                       on=:source=>:target)
        @. df.time += 1 # increase internal process time

        push!(present, df) # record edges in "present" list
    end


    function landslides(dataframe, delay)
        df = filter(:type_source => x -> x=="landslide", dataframe)
        # generate new landslide if time has come else wait (assume pareto probability distribution ... which is wrong and to be defined at later stage)
        @. df.magnitude = ifelse(df.time == df.global_time, rand(Pareto(3, 1000)), df.magnitude)
        # reset delay to 3 time units if time has come for a reset (assume delayed of 3 units of time to trigger landslide) or wait
        @. df.time = ifelse(df.time == df.global_time, df.time + delay, df.time)

        push!(present, df)
    end


    function catchment(dataframe, delay)
        # current catchment to river if time has come otherwise wait
        df = filter(:type_source=> x -> x=="catchment", dataframe)
        @. df.magnitude = ifelse(df.time == df.global_time, rand(Pareto(3, 1000)), df.magnitude)
        @. df.time = ifelse(df.time == df.global_time, df.time + delay, df.time)
        push!(present, df)

        # deal with the impact of catchment on rivers by cascading the runoff magnitude to rivers if time has come
        df = filter(:source => x -> x in Set(present[end].target), dataframe)
        # simulate all possible configurations of catchment/river
        df = outerjoin(df, 
                    present[end], # catchment behavior
                    on=:source=>:target, 
                    makeunique=true)
        # if time has come (time > global time), catchment runoff to river ELSE 100 (base line value), 
        @. df.magnitude = ifelse(df.time_1 - delay == df.global_time, # due
                            df.magnitude_1, # magnitude of river is magnitude from catchment
                            100) # else magnitude is a base line value of 100 from catchment
        @. df.time += 1
        # println("df - river / catchment")
        # println(df)

        push!(present, df[:, [:source, :target, :type_source, :magnitude, :time, :global_time]])
    end


    function concatenate_results(list_dataframe)
        cat = reduce(vcat, list_dataframe) 
        gdf = groupby(cat, [:source, :target, :type_source, :time, :global_time])
        present = combine(gdf, [:magnitude] .=> sum; renamecols=false) # sum magnitude on edges to common node (have to watch the magnitude units!)
        return present
    end
end


# set up #############################
begin 
    # set up input parameters
    network = DataFrame(source = ["river1", "river2", "river3", "river4", "river5",
        "dam", "river6", "river7", "river8", "river9",
        "landslide", "landslide", "river8", "catchment1", "catchment2"], 
        target = ["river2", "river3", "river4", "river5",
        "dam", "river6", "river7", "river8", "river9", "river10",
        "river9", "infrastructure", "infrastructure", "river1", "river2"],
        type_source= ["river", "river", "river", "river", "river",
        "dam", "river", "river", "river", "river",
        "landslide", "landslide", "river", "catchment", "catchment"],
        magnitude = [1001.0, 1002.0, 1003.0, 1004.0, 1005.0, 1006.0, 1007.0, 1008.0, 1009.0, 1010.0, 0.0, 0.0, 1009.0, 0.0, 0.0])

    global_time = 1
    @. network.time = global_time
    @. network.global_time = global_time

    clock = []
    push!(clock, network)
end


# Algorithm ##########################
for global_time in tqdm(1:100000)

    # println("global time : $global_time")

    global present = []
    past = clock[end]
    @. past.global_time = global_time

    river_and_dams(past)
    landslides(past)
    catchment(past)
    
    present = concatenate_results(present)

    push!(clock, present)
    
end

clock