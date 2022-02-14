using Pkg
Pkg.activate(@__DIR__)

using Graphs
using GraphPlot
using DataFrames, Random, Distributions


# input
begin
    # edge_order would be DEM value
    df = DataFrame(source = ["river1", "river2", "river3", "river4", "river5",
    "dam", "river6", "river7", "river8", "river9",
    "landslide", "landslide", "river8", "catchment1", "catchment2"], 
    target = ["river2", "river3", "river4", "river5",
    "dam", "river6", "river7", "river8", "river9", "river10",
    "river9", "infrastructure", "infrastructure", "river1", "river2"],
    type_source= ["river", "river", "river", "river", "river",
    "dam", "river", "river", "river", "river",
    "landslide", "landslide", "river", "catchment", "catchment"],
    type_target= ["river", "river", "river", "river",
    "dam", "river", "river", "river", "river", "river1",
    "river", "infrastructure", "infrastructure", "river", "river"],
    source_ID = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 11, 9, 13, 14],
    target_ID = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 10, 12, 12, 1, 2],
    edge_order = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0, 0, 0, 0, 0])

    # input parameters
    df_clock = []
    river_base_flow = 1000.0

    # Add the discharge
    df.magnitude .= river_base_flow

    # Parameters for pareto distributions
    α = 3
    θ = 100

    # create delay attribute for each edges
    df.delay .= 0
    df.time .= 0

    # state @ t0
    push!(df_clock, df)
end

# algorithm
time_max = 2

# for t in 1:time_max

# start from the last state
d = df_clock[end]

# Random events that can happened randomly at each time
# Create artificial runoff for each catchments (should come from weather pattern and volcanic activity)
runoff(x) = (x=="catchment") ? rand(Pareto(α, θ), 1)[1] : 0
rof = runoff.(df.type)

# Create artificial landslide for each landslide source
landslide(x) = (x=="landslide") ? rand(Pareto(α, θ), 1)[1] : 0
ls = landslide.(df.type, df.magnitude)

# Add magnitude to edges
d.magnitude = rof .+ ls

# propagate flow downstream
next_df = select(d, Not(:source))
d = innerjoin(d, next_df, on=[:source => :target], makeunique=true)

# record event at time t and "remove" delay
d.time .= t
d.delay .-= 1
push!(df_clock, d)

# end