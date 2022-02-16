using Pkg
Pkg.activate(@__DIR__)

using Graphs
using GraphPlot
using DataFrames, Random, Distributions

begin
    df = DataFrame(source = ["river1", "river2", "river3", "river4", "river5",
    "dam", "river6", "river7", "river8", "river9",
    "landslide", "landslide", "river8", "catchment1", "catchment2"], 
    target = ["river2", "river3", "river4", "river5",
    "dam", "river6", "river7", "river8", "river9", "river10",
    "river9", "infrastructure", "infrastructure", "river1", "river2"],
    type_source= ["river", "river", "river", "river", "river",
    "dam", "river", "river", "river", "river",
    "landslide", "landslide", "river", "catchment", "catchment"])
    # type_target= ["river", "river", "river", "river",
    # "dam", "river", "river", "river", "river", "river1",
    # "river", "infrastructure", "infrastructure", "river", "river"],
    # source_ID = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 11, 9, 13, 14],
    # target_ID = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 10, 12, 12, 1, 2],
    # edge_order = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0, 0, 0, 0, 0])

    @. df.magnitude = ifelse((df.type_source == "river") | (df.type_source == "dam"), 1000.0, 0.0) # base discharge
    @. df.delay = 1
    @. df.time = 0
end


clock = []
futures = []
push!(clock, df)

for time in 1:10
    global last_df = clock[end] # last_df state of the network
    
    # update original network to be updated to current state
    @. last_df.time = time

    # Create random temporal events (here landslide volume and runoff) during the time interval if delay of the previous event is passed
    @. last_df.magnitude = ifelse(((last_df.type_source == "landslide") | (last_df.type_source == "catchment")) & (last_df.delay == time), rand(Pareto(3, 1000)), last_df.magnitude)

    # and reset delay depending on type (assuming runoff takes 2 time intervals) if passed
    @. last_df.delay = ifelse((last_df.type_source == "catchment") & (last_df.delay == time), time + 2, last_df.delay)

    # keep currently activating edge list & delayed node to the next time interval
    global delayed = filter([:delay, :time] => (x,y) -> x>y, last_df) # keep delayed edges
    delayed = delayed[:, [:source, :target, :type_source, :magnitude, :delay, :time]]
    global current = filter([:delay, :time] => (x,y) -> x<=y, last_df) # keep active edges
    current = current[:, [:source, :target, :type_source, :magnitude, :delay, :time]]

    current = vcat(current, delayed)
    
    # move active edges forward (target becomes source in the orginal dataset) based on their type
    @. current.source = ifelse((current.type_source == "river") | (current.type_source == "dam"), current.target, current.source)
    current = current[:, [:source, :type_source, :magnitude, :delay, :time]]
    
    # NEED TO GO BACK TO THE INITIAL NETWORK SETUP BUT WITH THE UPDATED MAGNITUDE DELAY TIME

    push!(clock, current)
end