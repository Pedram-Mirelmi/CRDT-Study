defmodule DmCasesTest do
  require Logger
  alias Analyzer.CrdtAnalyzer
  alias Utils.SimulationUtility
  alias Topologies.TopologyUtilities
  import Utils.SimulationParams
  use ExUnit.Case, async: false


  @tag :skip
  test "fresh node join" do
    Enum.each(study_cases(), fn {node_module, %{crdt_cases: crdt_cases, conf_cases: conf_cases}} ->
      Enum.each(conf_cases, fn {conf_name, node_conf} ->
        Enum.each(crdt_cases, fn {crdt_data_type, crdt_module} ->
          Enum.each(topology_cases(), fn {topology_name, n_nodes, topology_setup_func, topology_teardown_fun} ->

            Logger.debug("Starting simulation(Fresh join): Topology=#{topology_name}, Node=#{node_module |> Module.split() |> List.last()}, Conf=#{conf_name}, CRDT=#{crdt_module |> Module.split() |> List.last()}")


            topology_setup_func.(node_module, node_conf)

            # start the node to be joined later
            extra_node_name = "node#{n_nodes}"
            BaseNode.start(extra_node_name, node_conf, node_module)

            # update on main component nodes
            SimulationUtility.perform_update_on_nodes(n_nodes, SimulationUtility.repetitions(), crdt_data_type, crdt_module, :also_immediately, 20)

            SimulationUtility.perform_manual_sync_on_nodes(n_nodes, n_nodes, 20)

            :timer.sleep(100)
            # Now, connect it to one of the existing nodes and it should automatically sync
            BaseLinkLayer.connect("node0", extra_node_name)

            # wait for the sync to take effect
            :timer.sleep(200)

            metrics_dir = if Utility.debugging(), do: "dm_metrics_debug", else: "dm_metrics"

            module_name = node_module |> Module.split() |> List.last()
            crdt_name = crdt_module |> Module.split() |> List.last()
            filename = "[Fresh Join] | #{topology_name} | #{module_name} | #{conf_name} | #{Atom.to_string(:also_immediately)} | #{crdt_data_type}-#{crdt_name}.json"
            SimulationUtility.extract_and_save_metrics(n_nodes+1, metrics_dir, filename)

            CrdtAnalyzer.reset()
            # reset analyzer
            topology_teardown_fun.()
            BaseNode.stop(extra_node_name)
            :timer.sleep(200)

          end)
        end)
      end)
    end)
  end

  @tag timeout: :infinity
  test "Crash then Recover" do
    Enum.each(study_cases(), fn {node_module, %{crdt_cases: crdt_cases, conf_cases: conf_cases}} ->
      Enum.each(conf_cases, fn {conf_name, node_conf} ->
        Enum.each(crdt_cases, fn {crdt_data_type, crdt_module} ->
          Enum.each(topology_cases(), fn {topology_name, n_nodes, topology_setup_func, topology_teardown_fun} ->

            Logger.debug("Starting simulation(Crash then Recover): Topology=#{topology_name}, Node=#{node_module |> Module.split() |> List.last()}, Conf=#{conf_name}, CRDT=#{crdt_module |> Module.split() |> List.last()}")


            topology_setup_func.(node_module, node_conf)
            # start the extra node and connect to later disconnect
            extra_node_name = "node#{n_nodes}"
            BaseNode.start(extra_node_name, node_conf, node_module)
            BaseLinkLayer.connect("node0", extra_node_name)

            # update on all nodes
            SimulationUtility.perform_update_on_nodes(n_nodes+1, SimulationUtility.repetitions(), crdt_data_type, crdt_module, :also_immediately, 20)


            SimulationUtility.perform_manual_sync_on_nodes(n_nodes+1, n_nodes+1, 20)



            :timer.sleep(100)
            # Logger.debug("first assert")
            # SimulationUtility.assert_states_equal(SimulationUtility.get_nodes_crdts(n_nodes+1))
            # Now, disconnect it to one of the existing nodes
            for i <- 0..4 do

              BaseLinkLayer.disconnect("node0", extra_node_name)

              # :timer.sleep(100)

              # update on the main component
              SimulationUtility.perform_update_on_nodes(n_nodes, SimulationUtility.repetitions(), crdt_data_type, crdt_module, :also_immediately, 20, 0, 2000)

              # sync the big component
              SimulationUtility.perform_manual_sync_on_nodes(n_nodes, n_nodes, 20)
              # wait for updates to propagate
              # :timer.sleep(100)

              # Logger.debug("second assert")
              # SimulationUtility.assert_states_equal(SimulationUtility.get_nodes_crdts(n_nodes))

              BaseLinkLayer.connect("node0", extra_node_name)
              # :timer.sleep(100)

              SimulationUtility.perform_manual_sync_on_nodes(n_nodes+1, n_nodes+1, 20)

              # :timer.sleep(100)
            end

            metrics_dir = if Utility.debugging(), do: "dm_metrics_debug", else: "dm_metrics"

            module_name = node_module |> Module.split() |> List.last()
            crdt_name = crdt_module |> Module.split() |> List.last()
            filename = "[Crash 5 times then Recover] | #{topology_name} | #{module_name} | #{conf_name} | #{Atom.to_string(:also_immediately)} | #{crdt_data_type}-#{crdt_name}.json"
            SimulationUtility.extract_and_save_metrics(n_nodes+1, metrics_dir, filename)

            # reset analyzer
            CrdtAnalyzer.reset()
            BaseNode.stop(extra_node_name)
            topology_teardown_fun.()

          end)
        end)
      end)
    end)
  end
end
