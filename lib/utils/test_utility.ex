defmodule Utils.TestUtility do
require Logger

  def trigger_set_add_update(n_nodes, n_objects, object_type, n_elements_per_object, node_module, pause) do
    Process.spawn(fn ->
      for i <- 0..(n_objects-1) do
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


  def get_nodes_states(n_nodes, node_module) do
    Map.new(0..(n_nodes-1), fn i ->
      node = "node" <> Integer.to_string(i)
      node_state = node_module.get_state(node)
      db = node_state.db
      {node, db}
    end)
  end
end
