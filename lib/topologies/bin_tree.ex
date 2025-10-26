defmodule Topologies.BinTree do
  require Logger
  alias Topologies.BinTree
  defstruct root: nil, left_tree: nil, right_tree: nil

  def new(n, naming_from, node_module, node_conf) when n > 0 do
    BaseNode.start("node#{naming_from}", node_conf, node_module)
    {left_tree, left_n_nodes} = BinTree.new(Integer.floor_div(n-1, 2), naming_from + 1, node_module, node_conf)
    {right_tree, right_n_nodes} = BinTree.new(n-1-left_n_nodes, naming_from + 1 + left_n_nodes, node_module, node_conf)

    constructed_tree = %BinTree{root: "node#{naming_from}", left_tree: left_tree, right_tree: right_tree}

    if left_tree != nil do
      BaseLinkLayer.connect(constructed_tree.root, left_tree.root)
    end
    if right_tree != nil do
      BaseLinkLayer.connect(constructed_tree.root, right_tree.root)
    end

    {
      constructed_tree,
      1 + left_n_nodes + right_n_nodes
    }
  end

  def new(n, _, _, _) when n <= 0 do
    {nil, 0}
  end

  def traverse(%BinTree{root: root, left_tree: left_tree, right_tree: right_tree}) do
    Logger.info("on node #{inspect(root)}; going to left:")
    BinTree.traverse(left_tree)
    Logger.info("on node #{inspect(root)}; going to right")
    BinTree.traverse(right_tree)
    Logger.info("going up")
  end

  def traverse(nil) do
    Logger.info("nil!")
  end

end
