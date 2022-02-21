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
    "landslide", "landslide", "river", "catchment", "catchment"],
    magnitude = [1001.0, 1002.0, 1003.0, 1004.0, 1005.0, 1006.0, 1007.0, 1008.0, 1009.0, 1010.0, 0.0, 0.0, 1009.0, 0.0, 0.0])
    # type_target= ["river", "river", "river", "river",
    # "dam", "river", "river", "river", "river", "river1",
    # "river", "infrastructure", "infrastructure", "river", "river"],
    # source_ID = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 11, 9, 13, 14],
    # target_ID = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 10, 12, 12, 1, 2],
    # edge_order = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0, 0, 0, 0, 0])
end


begin
    clock = []
    network = copy(df)
    push!(clock, network)
    past = clock[end]
    start_time = 0
    @. network.delay = 1
    @. network.time = start_time
end





time = 2

# # dealing with river nodes
# singular_events = ["landslide", "catchment"]
# past_event = filter([:type_source] => (x) -> ~(x in singular_events), past)
# # present_event = filter([:type_source] => (x) -> ~(x in singular_events), network)
# continuous_edges = innerjoin(network[:, Not([:magnitude, :delay, :time])], 
#                     past_event[:, [:target, :magnitude, :delay, :time]], 
#                     on=[:source=>:target], makeunique=true)

# # dealing with landslide and catchment nodes
# past_event = filter([:type_source] => (x) -> (x in singular_events), past)

# discrete_edges = innerjoin(network[:, [:source, :target, :type_source]],
#                     past_event[:, [:target, :magnitude, :delay, :time]], 
#                     on=[:source => :target])

# # concate dataframes together
# network_t = vcat(continuous_edges, discrete_edges, past_event) # take into account several edges branching into one node
# network_t = groupby(network_t, [:source, :target])
# network_t = combine(network_t, :magnitude => sum)



begin
    clock = []
    network = copy(df)
    push!(clock, network)
    past = clock[end]
    start_time = 0
    @. network.delay = 1
    @. network.time = start_time
end


time = 2


for edge in eachrow(network)
    edge.time = time

    if (edge.source in past.target) | (edge.type_source != "landslide")
        println("Current edge Source : $(edge.source)")
        println(edge)
        past_event = past[past.target .== edge.source, :]
        println("past_event")
        println(past_event)
        edge.magnitude = sum(past_event.magnitude)
        edge.delay = time + 1
    
    else 
        if edge.delay == time
            edge.magnitude = rand(Pareto(3, 1000))
            edge.delay = time + 5 
        end
    end
end

push!(clock, network)


for i in 1:nrow(network) # access the network one edge at a time
    @. network.time = time
    println("PRESENT")
    println(network[[i], :])

    # access previous events
    past_event = past[past.target .== network.source[i], :]
    println("PAST")
    println(past_event)

    for j in 1:nrow(past_event)
        addition = []
        # if past event is landslide and time is due
        if past_event.type_source[j] == "landslide" && (past_event.delay[j] == time)
            network[[i], :] = past_event[[j], :] # copy past event to present event
            network.magnitude[i] = rand(Pareto(3, 1000))
            network.delay[i] = time + 5 # assuming landslide make 5 time units to impact

        elseif past_event.type_source[j] == "landslide" && (past_event.delay[j] != time)
            network[[i], :] = past_event[[j], :]# copy past event to present event as is
            
        elseif (past_event.type_source[j] != "landslide") && (past_event.delay[j] == time)
            network.magnitude[i] += past_event.magnitude[j] # add flows from river and catchments



    end
end