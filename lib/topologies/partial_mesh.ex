defmodule Topologies.PartialMesh do
  require Logger
  alias Topologies.PartialMesh
  defstruct nodes: []

  def new(n_nodes, connectivity_degree, node_module, node_conf) when connectivity_degree > 2 do
    nodes_list =
      for i <- 0..(n_nodes-1) do
        name = "node#{i}"
        BaseNode.start(name, node_conf, node_module)
        node_module.start(name, node_conf)
        # {:ok, _pid} = SimNode.start_link(name, %{})
        name
      end

    for i <- 0..(n_nodes-1) do
      centeric_node = nodes_list |> Enum.at(i)
      previous_node = nodes_list |> Enum.at(i + n_nodes - 1 |> rem(n_nodes))
      next_node = nodes_list |> Enum.at(i+1)
      BaseLinkLayer.connect(centeric_node, next_node)
      BaseLinkLayer.connect(centeric_node, previous_node)
      # SimNode.connect(centeric_node, next_node)
      # SimNode.connect(centeric_node, previous_node)
      Logger.debug("connecting #{centeric_node} to #{previous_node} and #{next_node}")

      step_length = Integer.floor_div(n_nodes, connectivity_degree)
      n_conn_to_prev_nodes = ((connectivity_degree-2) / 2) |> :math.ceil() |> round()
      n_conn_to_next_nodes = ((connectivity_degree-2) / 2) |> :math.floor() |> round()

      if n_conn_to_prev_nodes > 0 do
        for j <- 0..(n_conn_to_prev_nodes-1) do
          other_node_index = (i - ((j+1)*step_length) + n_nodes) |> rem(n_nodes)
          other_node = nodes_list |> Enum.at(other_node_index)
          BaseLinkLayer.connect(centeric_node, other_node)
          # SimNode.connect(centeric_node, other_node)
          Logger.debug("connecting #{centeric_node} to #{other_node}")
        end
      end

      if n_conn_to_next_nodes > 0 do
        for j <- 0..(n_conn_to_next_nodes-1) do
          other_node_index = (i + ((j+1)*step_length)) |> rem(n_nodes)
          other_node = nodes_list  |> Enum.at(other_node_index)
          BaseLinkLayer.connect(centeric_node, other_node)

          # SimNode.connect(centeric_node, other_node)
          Logger.debug("connecting #{centeric_node} to #{other_node}")
        end
      end
    end

    %PartialMesh{nodes: nodes_list}
  end



end
