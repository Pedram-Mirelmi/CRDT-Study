defmodule Test.CrdtComparison do
  require Logger
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

  @repititions 10

  @node0 "node0"
  @node1 "node1"
  @node2 "node2"
  @node3 "node3"
  @node4 "node4"


  def study_cases() do
    %{
      # SB_Node => %{
      #   crdt_cases: [
      #     {:set, Set_GO_SB}
      #   ],
      #   conf_cases: [
      #     {"bp=true", SB_Node.default_conf() |> Map.put(:bp?, true)},
      #     {"bp=false", SB_Node.default_conf() |> Map.put(:bp?, false)}
      #   ]
      # },
      ND_Node => %{
        crdt_cases: [
          {:set, Set_GO_ND}
        ],
        conf_cases: [
          {"bp=true", ND_Node.default_conf() |> Map.put(:bp?, true)},
          {"bp=false", ND_Node.default_conf() |> Map.put(:bp?, false)}
        ]
      },
      # JD_Node => %{
      #   crdt_cases: [
      #     {:set, Set_GO_JD},
      #   ],
      #   conf_cases: [
      #     {"bp=true", JD_Node.default_conf() |> Map.put(:bp?, true)},
      #     # {"bp=false", JD_Node.default_conf() |> Map.put(:bp?, false)}
      #   ]
      # },
      # BD_Node => %{
      #   crdt_cases: [
      #     {:set, Set_GO_BD},
      #   ],
      #   conf_cases: [
      #     {"full push model", BD_Node.default_conf() |> Map.merge(%{bd_push_model1?: true, bd_push_model2?: true, bd_pull_model?: true})},
      #     {"only pull_model", BD_Node.default_conf() |> Map.merge(%{bd_push_model1?: false, bd_push_model2?: false, bd_pull_model?: true})},
      #     {"push_model1=true|push_model_2=false", BD_Node.default_conf() |> Map.merge(%{bd_push_model1?: true, bd_push_model2?: false, bd_pull_model?: true})},
      #   ]
      # }


    }
  end

  def topology_cases() do
    [
      {"Simple pair", 2, &TopologyUtilities.form_simple_pair/2, fn n_nodes -> SimulationUtility.stop_n_nodes(2) end},
      {"Centric node, 5 nodes", 5, fn node_module, node_conf -> TopologyUtilities.form_one_central_topology(5, node_module, node_conf) end, fn n_nodes -> SimulationUtility.stop_n_nodes(5) end},
      {"Diamond topology, 4 nodes", 4, &TopologyUtilities.form_dimond/2, fn n_nodes -> SimulationUtility.stop_n_nodes(4) end},
      {"Partial mesh, 10 nodes, 4 conn", 10, fn node_module, node_conf -> PartialMesh.new(10, 4, node_module, node_conf) end, fn n_nodes -> SimulationUtility.stop_n_nodes(10) end},
      {"Full mesh, 5 nodes", 5, fn node_module, node_conf -> TopologyUtilities.full_mesh(5, node_module, node_conf) end, fn n_nodes -> SimulationUtility.stop_n_nodes(5) end}
    ]
  end

  def sync_approaches() do
    [
      :also_immediately,
      :only_ultimately
    ]
  end


  @tag timeout: :infinity
  test "All" do
    Enum.each(study_cases(), fn {node_module, %{crdt_cases: crdt_cases, conf_cases: conf_cases}} ->
      Enum.each(conf_cases, fn {conf_name, node_conf} ->
        Enum.each(topology_cases(), fn {topology_name, n_nodes, topology_setup_func, topology_teardown_fun} ->
          Enum.each(crdt_cases, fn {crdt_data_type, crdt_module} ->
            Enum.each(sync_approaches(), fn sync_approach ->
              topology_setup_func.(node_module, node_conf)

              Logger.debug("Starting test: Topology=#{topology_name}, Node=#{node_module |> Module.split() |> List.last()}, Conf=#{conf_name}, CRDT=#{crdt_module |> Module.split() |> List.last()}, sync_approach=#{sync_approach}")
              key = {"key", crdt_module}

              for i <- 0..(@repititions*n_nodes-1) do
                target_node_index = rem(i, n_nodes)
                target_node_name = "node" <> Integer.to_string(target_node_index)
                update = SimulationUtility.sample_update(crdt_data_type, i)
                BaseNode.update(target_node_name, key, update)
                if sync_approach != :also_immediately do
                  BaseNode.sync_now(target_node_name)
                end
                :timer.sleep(20)
              end

              for _i <- 0..(n_nodes-1) do
                for j <- 0..(n_nodes-1) do
                  node_name = "node" <> Integer.to_string(j)
                  BaseNode.sync_now(node_name)
                  :timer.sleep(20)
                end
              end
              :timer.sleep(200)
              nodes_crdts = SimulationUtility.get_nodes_crdts(n_nodes)

              # :timer.sleep(50000000000)
              SimulationUtility.assert_states_equal(nodes_crdts)

              module_name = node_module |> Module.split() |> List.last()
              crdt_name = crdt_module |> Module.split() |> List.last()
              file_name = "metrics/#{topology_name} | #{module_name} | #{conf_name} | #{Atom.to_string(sync_approach)} | #{crdt_data_type}-#{crdt_name}.json"
              SimulationUtility.save_metrices(file_name)
              CrdtAnalyzer.reset()
              # reset analyzer
              topology_teardown_fun.(n_nodes)

            end)
          end)

        end)
      end)
    end)
  end




  # @tag timeout: :infinity
  @tag :skip
  test "Simple pair" do
    Enum.each(study_cases(), fn {node_module, crdt_cases} ->
      node_conf = node_module.default_conf() |> Map.put(:sync_interval, 2000000)
      SimulationUtility.form_simple_pair(node_module, node_conf)
      Enum.each(crdt_cases, fn {crdt_data_type, crdt_module} ->
        key = {"key", crdt_module}
        nodes = {@node0, @node1}
        for i <- 0..(2*@repititions-1) do
          target_node_name = elem(nodes, rem(i, 2))
          update = SimulationUtility.sample_update(crdt_data_type, i)
          BaseNode.update(target_node_name, key, update)
          :timer.sleep(50)
          BaseNode.sync_now(target_node_name)
          :timer.sleep(50)
        end

        :timer.sleep(500)
        # :timer.sleep(50000000000)

        nodes_states = SimulationUtility.get_nodes_crdts(2)
        SimulationUtility.assert_states_equal(nodes_states)
        SimulationUtility.save_metrices(nodes_states, node_module, crdt_module, "simple pair toplogy | bp=true")
        # reset analyzer
        CrdtAnalyzer.reset()
        # reset nodes states
        SimulationUtility.reset_nodes_states(2)
      end)

      SimulationUtility.stop_n_nodes(2)
    end)
  end


end
