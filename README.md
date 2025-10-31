# A Comparative Study over Different CRDT Synchronization Approaches

In this repository, I've developed the necessary modules to run simulations for the following settings (so far):

- CRDTs
    - Pure state-based; `sb` directory and its submodules
        - GSet
    - Naive delta-based; `nd` directory and its submodules
        - GSet
        - Allows for Back Propagation optimization
    - Join Decomposition delta-based 
        - GSet
        - Allows for Back Propagation optimization
        - Automatically applies 'Remove Redundant' optimization
    - Big-Delta (using vector clocks)
        - GSet

- Topologies
    - Binary tree
    - Partial mesh with parameterized 'connectivity index' for nodes
    - Full mesh
    - Simple pair
    - Dimond
    - "Centric node"

- Sync method
    - immediately after each update
    - after all updates


# Overview

The actual runnable simulation codes are in the `/test/` directory. 

However these codes use a great deal of the simulation utility functions in `/lib/utils/simulation_params.ex` and `/lib/utils/simulation_utility.ex` modules.

## Nodes
Each node in the simulation is structured out of a Link Layer and the Node itself. Each one of these are concurrent independent BEAM processes (GenServers) for each node.

Due to high similarity in the code logic, `BaseNode` (Node layer) and `BaseLinkLayer` (Link Layer) has been developed to share some common logic which are the core GenServers for these two layers.

- `BaseLinkLayer`: Keeps the local node's neighbour peers, handles the main message communication among the nodes and passes the received messages to upper layer (Node). It acts as a abstract class that delagates the core logic to its concrete module which is given and stored at construction time (e.g. ND_Link_Layer) 

- `BaseNode`: Similarily acts as an abstract class that delagates the core logic to the concrete module. The concrete module (e.g. ND_Node) must implement the following callbacks:
    - `@callback initial_state(binary(), map()) :: map()`
    - `@callback ll_module() :: module()`
    - `@callback handle_update(map(), tuple(), tuple()) :: map()`
    - `@callback handle_ll_deliver(map(), tuple()) :: map()`
    - `@callback handle_periodic_sync(map()) :: map()`
    - `@callback handle_peer_full_sync(map(), binary()) :: map()`


### Concrete Implementations
Concrete implementation of each type of node is placed in its directory along with its other modules (e.g. its crdts, `db` or `buffer`)

## Analyzer (`CrdtAnalyzer`)
The independent running BEAM process (GenServer) to which nodes send statistics about their execution such as their current memory usage or their network traffic

It keeps these data in its state `AnalyzerState` module which can be retrieved at the end of a simulation by calling `CrdtAnalyzer.get_state/0`

It keeps time series information about nodes 
- incoming network traffic
- outgoing network traffic
- total database size (crdts' size)
- total state size (including buffer)

# Instruction on how to run simulations

As you can see all the simulation parameters have been placed in `/lib/utils/simulation_params.ex`. You can uncomment those you want and run multiple simulations in one go by running the following command:

```bash
$ mix test test/general_cases_test.exs
```

This might take some time depending on your chosen parameters and the number of resulted simulations.

You can create custome topologies by adding tuples to the literal list returned by `topology_cases` function in this format:

```elixir
{
    "Ring, 100 nodes", # topology short name;
    100, # number of nodes
    fn node_module, node_conf -> PartialMesh.new(100, 2, node_module, node_conf) end, # function for topology set up
    fn -> SimulationUtility.stop_n_nodes(100) end # function for topology teardown
}
```

This will run the general scenario given in the `Utils.SimulationUtility.run_simulation_for/10` function which is:
- bring up the cluster according to the `topology_setup_func`
- Performs local operations (based on the given `crdt_data_type`, e.g. :set will have add operation) for "`SimulationUtility.repetitions()`" times
- If `manual_sync_approach` is set to `:also_immediately`, it will force each node to do its periodic sync right after each local operation. 
- After all local operations, it will itterate over all nodes "`n_nodes`" times and force them to do their perodic sync once again. See  `Utils.SimulationUtility.perform_manual_sync_on_nodes/4` function. This will ensure all nodes' states converge
- Then it will go collect nodes' state and checks for convergence.
- Then gets the execution metrics from `CrdtAnalyzer` and write it to a file named after the execution's settings, e.g. `Partial mesh, 10 nodes, 4 conn | JD_Node | bp=true | also_immediately | set-Set_GO_JD.json`. Later, in the given python jupyter notebook `/python/plot.ipynb`, you can plot this data using various given functions. 

You can also write your own more complex and flexible scenarios and run them. For example, the scenario in which a node is crashed (or disconnected from the cluster) is given in `/test/dm_cases_test.exs` file which demonstrates the advantage of Big-Delta CRDTs.