defmodule Utils.SimulationUtility do
  alias ElixirLS.LanguageServer.Plugins.Util
  alias Utils.SimulationUtility
  alias Analyzer.CrdtAnalyzer
  use ExUnit.Case
  require Logger

  @long_text "Lorem ipsum dolor sit amet, consectetur "
  @short_text ""

  def repetitions() do
    if Utility.debugging(), do: 1, else: 10
  end

  def perform_update_on_nodes(n_nodes, n_times, crdt_data_type, crdt_module, manual_sync_approach, sleep_time, node_name_starting_from \\ 0, updates_starting_from \\ 0) do
    key = {"key", crdt_module}

    for i <- 0..(n_times*n_nodes-1) do
      target_node_index = rem(i, n_nodes) + node_name_starting_from
      target_node_name = "node" <> Integer.to_string(target_node_index)
      update = sample_update(crdt_data_type, i + updates_starting_from)
      BaseNode.update(target_node_name, key, update)
      if manual_sync_approach == :also_immediately do
        BaseNode.sync_now(target_node_name)
      end
      :timer.sleep(sleep_time)
    end
  end

  def perform_manual_sync_on_nodes(n_nodes, n_times, sleep_time, node_name_starting_from \\ 0) do
    for _i <- 0..(n_times-1) do
      for j <- 0..(n_nodes-1) do
        node_name = "node" <> Integer.to_string(j+node_name_starting_from)
        BaseNode.sync_now(node_name)
        :timer.sleep(sleep_time)
      end
    end
  end

  def extract_and_save_metrics(n_nodes, dir, filename) do
    nodes_crdts = get_nodes_crdts(n_nodes)

    converge_result = assert_states_equal(nodes_crdts)
    converge_result_file_prefix = if converge_result do "" else "[F] " end
    if not converge_result do Logger.warning("Didn't converge!") end

    # file_name = "#{metrics_dir}/#{custome_prefix}#{topology_name} | #{module_name} | #{conf_name} | #{Atom.to_string(manual_sync_approach)} | #{crdt_data_type}-#{crdt_name}.json"
    save_metrices_to_file("#{dir}/#{converge_result_file_prefix}#{filename}")
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


    perform_update_on_nodes(
      n_nodes,
      SimulationUtility.repetitions(),
      crdt_data_type,
      crdt_module,
      manual_sync_approach,
      10 # increase this 10ms if the simulation doesn't converge
    )


    perform_manual_sync_on_nodes(n_nodes, n_nodes, 10) # increase this 10ms if the simulation doesn't converge

    :timer.sleep(300)

    metrics_dir = if Utility.debugging(), do: "metrics_debug", else: "metrics"

    module_name = node_module |> Module.split() |> List.last()
    crdt_name = crdt_module |> Module.split() |> List.last()
    filename = "#{topology_name} | #{module_name} | #{conf_name} | #{Atom.to_string(manual_sync_approach)} | #{crdt_data_type}-#{crdt_name}.json"
    extract_and_save_metrics(n_nodes, metrics_dir, filename)

    CrdtAnalyzer.reset()
    # reset analyzer
    topology_teardown_fun.()
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

  def sample_update(:counter, _i) do
    {:increment, []}
  end

  def assert_states_equal(nodes_states) do
    one_elements_set = (nodes_states |> Map.values() |> MapSet.new() |> MapSet.size())
    result = one_elements_set == 1


    # Enum.each(nodes_states, fn {node1, state1} ->
    #   Enum.each(nodes_states, fn {node2, state2} ->
    #     if state1 != state2 do
    #       Logger.warning("States of #{node1} and #{node2} are not equal: \n\n#{inspect(state1)} \n\nvs \n\n #{inspect(state2)}\n\n==================\n\n")
    #     end
    #     # assert state1 == state2, "States of #{node1} and #{node2} are not equal: \n\n#{inspect(state1)} \n\nvs \n\n #{inspect(state2)}"
    #   end)
    # end)

    result
  end

  def get_nodes_crdts(n_nodes) do
    Map.new(0..(n_nodes-1), fn i ->
      node = "node" <> Integer.to_string(i)
      node_state = BaseNode.get_state(node)
      crdts = node_state.db.crdts
      {node, crdts}
    end)
  end

  def save_metrices_to_file(filename) do
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
