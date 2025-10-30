defmodule Utils.SimulationParams do
  alias Topologies.BinTree
  alias Topologies.TopologyUtilities
  alias Topologies.PartialMesh
  alias Crdts.Set_GO_BD
  alias Crdts.Set_GO_JD
  alias Crdts.Set_GO_ND
  alias Crdts.Set_GO_SB
  alias Utils.SimulationUtility
  alias BD.BD_Node
  alias JD.JD_Node
  alias ND.ND_Node
  alias SB.SB_Node

  def study_cases() do
    %{
      # SB_Node => %{
      #   crdt_cases: [
      #     {:set, Set_GO_SB}
      #   ],
      #   conf_cases: [
      #     {"updates_only", SB_Node.default_conf() |> Map.put(:sb_sync_method, :updates_only)},
      #     {"full_state", SB_Node.default_conf() |> Map.put(:sb_sync_method, :all)}
      #   ]
      # },
      # ND_Node => %{
      #   crdt_cases: [
      #     {:set, Set_GO_ND}
      #   ],
      #   conf_cases: [
      #     {"bp=true", ND_Node.default_conf() |> Map.put(:bp?, true)},
      #     {"bp=false", ND_Node.default_conf() |> Map.put(:bp?, false)}
      #   ]
      # },
      # JD_Node => %{
      #   crdt_cases: [
      #     {:set, Set_GO_JD},
      #   ],
      #   conf_cases: [
      #     {"bp=true", JD_Node.default_conf() |> Map.put(:bp?, true)},
      #     {"bp=false", JD_Node.default_conf() |> Map.put(:bp?, false)}
      #   ]
      # },
      BD_Node => %{
        crdt_cases: [
          {:set, Set_GO_BD},
        ],
        conf_cases: [
          # {"full push_model", BD_Node.default_conf() |> Map.merge(%{bd_push_model1?: true, bd_push_model2?: true, bd_pull_model?: true})},
          {"only pull_model", BD_Node.default_conf() |> Map.merge(%{bd_push_model1?: false, bd_push_model2?: false, bd_pull_model?: true})},
          # {"push_model1=true+push_model_2=false", BD_Node.default_conf() |> Map.merge(%{bd_push_model1?: true, bd_push_model2?: false, bd_pull_model?: true})},
          # {"full push_model+random", BD_Node.default_conf() |> Map.merge(%{bd_push_model1?: true, bd_push_model2?: true, bd_pull_model?: true, bd_sync_method: :random})},
          # {"only pull_model+random", BD_Node.default_conf() |> Map.merge(%{bd_push_model1?: false, bd_push_model2?: false, bd_pull_model?: true, bd_sync_method: :random})},
          # {"push_model1=true+push_model_2=false+random", BD_Node.default_conf() |> Map.merge(%{bd_push_model1?: true, bd_push_model2?: false, bd_pull_model?: true, bd_sync_method: :random})},
        ]
      }


    }
  end

  def topology_cases() do
    [
      {"Simple pair", 2, &TopologyUtilities.form_simple_pair/2, fn -> SimulationUtility.stop_n_nodes(2) end},
      # {"Centric node, 5 nodes", 5, fn node_module, node_conf -> TopologyUtilities.form_one_central_topology(5, node_module, node_conf) end, fn -> SimulationUtility.stop_n_nodes(5) end},
      # {"Diamond topology", 4, &TopologyUtilities.form_dimond/2, fn -> SimulationUtility.stop_n_nodes(4) end},
      # {"Partial mesh, 10 nodes, 4 conn", 10, fn node_module, node_conf -> PartialMesh.new(10, 4, node_module, node_conf) end, fn -> SimulationUtility.stop_n_nodes(10) end},
      # {"Full mesh, 5 nodes", 5, fn node_module, node_conf -> TopologyUtilities.full_mesh(5, node_module, node_conf) end, fn -> SimulationUtility.stop_n_nodes(5) end},
      # {"Tree, 5 nodes", 5, fn node_module, node_conf -> BinTree.new(5, 0, node_module, node_conf) end, fn -> SimulationUtility.stop_n_nodes(5) end},
      # {"Tree, 7 nodes", 7, fn node_module, node_conf -> BinTree.new(7, 0, node_module, node_conf) end, fn -> SimulationUtility.stop_n_nodes(7) end}
    ]
  end

  def sync_approaches() do
    [
      :also_immediately,
      :only_ultimately
    ]
  end
end
