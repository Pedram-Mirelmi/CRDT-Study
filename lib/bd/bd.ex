defmodule BD.BigDelta do

  alias Topologies.BinTree
  alias BD.BD_Node
  alias Topologies.PartialMesh

  def start(n, conn_degree, %{topology: :partial_mesh}, conf) do
    PartialMesh.new(
      n,
      conn_degree,
      start_fun(conf),
      connect_fun()
    )
  end

  def start(n, %{topology: :tree}, conf) do
    BinTree.new(
      n,
      0,
      start_fun(conf),
      connect_fun()
    )
  end


  def update(node_name, key, update) do
    BD_Node.update(node_name, key, update)
  end

  def start_fun(conf) do
    fn name ->
      {:ok, _pid} = BD_Node.start_link(name, conf)
    end
  end

  def connect_fun() do
    fn n1, n2 ->
      :ok = BD_Node.connect(n1, n2)
    end
  end


end
