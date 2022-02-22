using Pkg
Pkg.activate(@__DIR__)

using Graphs
using GraphPlot
using DataFrames, Random, Distributions


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

global_time = 0
@. network.time = global_time

clock = []
push!(clock, network)

for global_time in ProgressBar(1:1000)

    present = []
    past = clock[end]
    
    # RIVERS & DAMS #########################################################################
    df = filter([:type_source] => (x) -> x=="river" || x=="dam", past)
    # past_df = filter([:type_source] => (x) -> x=="river", past)
    df = innerjoin(df[:, Not([:magnitude, :time])], 
                df[:, [:target, :magnitude, :time]], 
                on=:source=>:target)
    @. df.time += 1
    push!(present, df)

    
    # LANDSLIDES ###########################################################################
    df = filter([:type_source] => (x) -> x=="landslide", past)
    @. df.time += 1
    # generate new landslide if time has come else wait (assume pareto probability distribution ... which is wrong and to be defined at later stage)
    @. df.magnitude = ifelse(df.time > global_time, rand(Pareto(3, 1000)), df.magnitude)
    # reset delay to 3 time units if time has come for a reset
    @. df.time = ifelse(df.time > global_time, global_time + 3, df.time)
    push!(present, df)


    # CATCHMENTS ##########################################################################
    # current catchment to river if time has come otherwise wait
    df = filter([:type_source] => (x) -> x=="catchment", past)
    @. df.time += 1
    @. df.magnitude = ifelse(df.time > global_time, rand(Pareto(3, 1000)), df.magnitude)
    @. df.time = ifelse(df.time > global_time, global_time + 5, df.time)
    push!(present, df)

    # deal with the impact of catchment on rivers by cascading the runoff magnitude to rivers if time has come
    df = filter([:source] => (x) -> x in Set(present[end].target), past)
    # simulate all possible configurations of catchment/river
    df = outerjoin(df, 
                present[end], # catchment behavior
                on=:source=>:target, 
                makeunique=true)
    # if time has come (time > global time), catchment runoff to river ELSE 100 (base line value), 
    @. df.magnitude = ifelse(global_time > df.time_1, # due
                        df.magnitude_1, 
                        100) # could be updated to match other nodes
    @. df.time += 1
    push!(present, df[:, [:source, :target, :type_source, :magnitude, :time]])


    # CONCATENATE PRESENT NETWORK STATE #####################################################
    cat = reduce(vcat, present)

    present = @chain cat begin
        groupby([:source, :target, :type_source])
        combine(:magnitude => sum => :magnitude)
    end

    present = innerjoin(present, 
                        cat[:, [:source, :target, :time]], 
                        on=[:source, :target])

    push!(clock, present)
end