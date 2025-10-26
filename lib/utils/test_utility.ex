defmodule Utils.TestUtility do
  alias Analyzer.CrdtAnalyzer
  alias Topologies.PartialMesh
  use ExUnit.Case
  require Logger

  # @long_text String.duplicate(" Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", 20)
  @long_text "l"

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

  def sample_update(:set, i) do
    {:add, ["element" <> Integer.to_string(i) <> @long_text]}
  end

  def assert_states_equal(nodes_states) do
    one_elements_set = (nodes_states |> Map.values() |> MapSet.new() |> MapSet.size())
    assert one_elements_set == 1, "Nodes states are not equal: #{inspect(nodes_states |> Map.values())}"
    Logger.debug("Nodes states are equal: #{inspect(nodes_states |> Map.values() |> Enum.at(0))}")

  end

  def reset_nodes_states(n_nodes) do
    for i <- 0..(n_nodes-1) do
      node_name = "node" <> Integer.to_string(i)
      BaseNode.reset_state(node_name, %{sync_interval: 2000000})
    end
  end

  def get_nodes_crdts(n_nodes) do
    Map.new(0..(n_nodes-1), fn i ->
      node = "node" <> Integer.to_string(i)
      node_state = BaseNode.get_state(node)
      crdts = node_state.db.crdts
      {node, crdts}
    end)
  end

  def save_metrices(node_module, crdt_type) do
    filename = "metrics/" <> Atom.to_string(node_module) <> "_" <> Atom.to_string(crdt_type) <> ".json"

    Logger.debug("Saving metrics to #{filename}")

    content =
      CrdtAnalyzer.get_state()
        |> Map.from_struct()
        |> Jason.encode!(pretty: true)

    File.write!(filename, content)
  end

  # 4 nodes in diamond topology
  def form_dimond(node_module, node_conf) do
    PartialMesh.new(4, 2, node_module, node_conf)
  end

  def form_simple_pair(node_module, node_conf) do
    {:ok, _pid0} = node_module.start("node0", node_conf)
    {:ok, _pid1} = node_module.start("node1", node_conf)

    BaseLinkLayer.connect("node0", "node1")
  end

  def stop_n_nodes(n_nodes) do
    for i <- 0..(n_nodes-1) do
      node_name = "node" <> Integer.to_string(i)
      BaseNode.stop(node_name)
    end
  end

end
