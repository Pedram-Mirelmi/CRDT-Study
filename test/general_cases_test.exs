defmodule Test.CrdtComparison do
  require Logger
  import Utils.SimulationParams
  alias Topologies.BinTree
  alias Topologies.TopologyUtilities
  alias Topologies.PartialMesh
  alias Analyzer.CrdtAnalyzer
  alias Crdts.Set_GO_BD
  alias Crdts.Set_GO_JD
  alias Crdts.Set_GO_ND
  alias Crdts.Set_GO_SB
  alias Utils.SimulationUtility
  alias BD.BD_Node
  alias JD.JD_Node
  alias ND.ND_Node
  alias SB.SB_Node
  use ExUnit.Case


  @tag timeout: :infinity
  test "All" do
    Enum.each(study_cases(), fn {node_module, %{crdt_cases: crdt_cases, conf_cases: conf_cases}} ->
      Enum.each(conf_cases, fn {conf_name, node_conf} ->
        Enum.each(topology_cases(), fn {topology_name, n_nodes, topology_setup_func, topology_teardown_fun} ->
          Enum.each(crdt_cases, fn {crdt_data_type, crdt_module} ->
            Enum.each(sync_approaches(), fn manual_sync_approach ->
              SimulationUtility.run_simulation_for(
                topology_setup_func,
                topology_teardown_fun,
                topology_name,
                n_nodes,
                node_module,
                node_conf,
                conf_name,
                crdt_data_type,
                crdt_module,
                manual_sync_approach
              )
            end)
          end)
        end)
      end)
    end)
  end

end
