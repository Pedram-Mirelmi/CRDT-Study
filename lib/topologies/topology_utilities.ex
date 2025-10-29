defmodule Topologies.TopologyUtilities do
  alias Topologies.BinTree
  alias Topologies.PartialMesh
  # 4 nodes in diamond topology
  def form_dimond(node_module, node_conf) do
    PartialMesh.new(4, 2, node_module, node_conf)
  end

  def form_simple_pair(node_module, node_conf) do
    BinTree.new(2, 0, node_module, node_conf)
  end

  def form_one_central_topology(n_nodes, node_module, node_conf) do
    PartialMesh.new(n_nodes, 2, node_module, node_conf)
    for i <- 1..(n_nodes-1) do
        node_name = "node" <> Integer.to_string(i)
        BaseNode.connect("node0", node_name)
      end
  end

  def full_mesh(n_nodes, node_module, node_conf) do
    Enum.each(0..(n_nodes-1), fn i ->
      name = "node#{i}"
      BaseNode.start(name, node_conf, node_module)
    end)
    Enum.each(0..(n_nodes-1), fn i ->
      Enum.each(0..(n_nodes-1), fn j ->
        if i != j do
          node_name_i = "node#{i}"
          node_name_j = "node#{j}"
          BaseNode.connect(node_name_i, node_name_j)
        end
      end)
    end)
  end

end
