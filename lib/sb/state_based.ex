defmodule StudyCases.StateBased do
alias Topology.PartialMesh
alias Topologies.BinTree
alias Node.SB_Node

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

  def start_fun(conf) do
    fn name ->
      {:ok, _pid} = SB_Node.start_link(name, conf)
    end
  end

  def connect_fun() do
    fn n1, n2 ->
      :ok = SB_Node.connect(n1, n2)
    end
  end

end
