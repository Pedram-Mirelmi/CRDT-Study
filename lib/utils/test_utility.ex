defmodule Utils.SimulationUtility do
  alias Analyzer.CrdtAnalyzer
  use ExUnit.Case
  require Logger

  @long_text "Lorem ipsum dolor sit amet, consectetur "
  @short_text ""

  @repititions 10

  def trigger_set_add_update(n_nodes, n_objects, object_type, n_elements_per_object, node_module, pause) do
    Process.spawn(fn ->
      for _i <- 0..(n_objects-1) do
        object_key_bin = "set-" <> Integer.to_string(n_objects)
        for j <- 0..(n_elements_per_object-1) do
          :timer.sleep(pause)
          element = object_key_bin <> "-e-" <> Integer.to_string(j)
          update = {:add, [element]}
          node_index = :erlang.phash2(j, n_nodes)
          node_name = "node" <> Integer.to_string(node_index)
          node_module.update(node_name, {object_key_bin, object_type}, update)
        end
      end
    end,
    [])
  end

  def run_simulation_for(
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
  ) do
    topology_setup_func.(node_module, node_conf)

    Logger.debug("Starting simulation: Topology=#{topology_name}, Node=#{node_module |> Module.split() |> List.last()}, Conf=#{conf_name}, CRDT=#{crdt_module |> Module.split() |> List.last()}, sync_approach=#{manual_sync_approach}")
    key = {"key", crdt_module}

    for i <- 0..(@repititions*n_nodes-1) do
      target_node_index = rem(i, n_nodes)
      target_node_name = "node" <> Integer.to_string(target_node_index)
      update = sample_update(crdt_data_type, i)
      BaseNode.update(target_node_name, key, update)
      if manual_sync_approach != :also_immediately do
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
    nodes_crdts = get_nodes_crdts(n_nodes)

    # :timer.sleep(50000000000)
    assert_states_equal(nodes_crdts)

    module_name = node_module |> Module.split() |> List.last()
    crdt_name = crdt_module |> Module.split() |> List.last()
    file_name = "metrics/#{topology_name} | #{module_name} | #{conf_name} | #{Atom.to_string(manual_sync_approach)} | #{crdt_data_type}-#{crdt_name}.json"
    save_metrices(file_name)
    CrdtAnalyzer.reset()
    # reset analyzer
    topology_teardown_fun.(n_nodes)
  end

  def get_long_text() do
    if Utility.debugging() do
      @short_text
    else
      repetition = Statistics.Distributions.Normal.rand(15, 2) |> Float.round() |> trunc()
      String.duplicate(@long_text, repetition)
    end
  end

  def sample_update(:set, i) do
    {:add, ["element-" <> Integer.to_string(i) <> "-" <> get_long_text()]}
  end

  def assert_states_equal(nodes_states) do
    # one_elements_set = (nodes_states |> Map.values() |> MapSet.new() |> MapSet.size())
    # assert one_elements_set == 1, "Nodes states are not equal: #{inspect(nodes_states |> Map.values())}"
    Enum.each(nodes_states, fn {node1, state1} ->
      Enum.each(nodes_states, fn {node2, state2} ->
        assert state1 == state2, "States of #{node1} and #{node2} are not equal: #{inspect(state1)} \n\nvs \n\n #{inspect(state2)}"
      end)
    end)
    # Logger.debug("Nodes states are equal: #{inspect(nodes_states |> Map.values() |> Enum.at(0))}")

  end

  def get_nodes_crdts(n_nodes) do
    Map.new(0..(n_nodes-1), fn i ->
      node = "node" <> Integer.to_string(i)
      node_state = BaseNode.get_state(node)
      crdts = node_state.db.crdts
      {node, crdts}
    end)
  end

  def save_metrices(filename) do
    # Logger.debug("Saving metrics to #{filename}")

    content =
      CrdtAnalyzer.get_state()
        |> Map.from_struct()
        |> Jason.encode!(pretty: true)

    File.write!(filename, content)
  end



  def stop_n_nodes(n_nodes) do
    for i <- 0..(n_nodes-1) do
      node_name = "node" <> Integer.to_string(i)
      BaseNode.stop(node_name)
    end
  end

end
