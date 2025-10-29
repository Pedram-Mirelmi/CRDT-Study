defmodule JD.GSet_JD do
  alias Jd.JoinDecomposition
  alias StudyCases.NaiveDelta
  alias JD.JD_Node
  alias Crdts.Set_GO_JD
  alias Utils.SimulationUtility
  alias Topologies.BinTree
  alias StudyCases.StateBased
  use ExUnit.Case

  @n_nodes 2
  @set_objects 1
  @set_elements 20


  @update_pause 40

  @sync_interval 150
  @bp? true

  test "test1" do
    {tree, n_nodes} = JoinDecomposition.start(@n_nodes, %{topology: :tree}, conf())


    SimulationUtility.trigger_set_add_update(@n_nodes, @set_objects, Set_GO_JD, @set_elements, JD_Node, @update_pause)

    :timer.sleep(2000)

    states = SimulationUtility.get_nodes_crdts(@n_nodes, JD_Node)
    IO.inspect(states)

    CrdtAnalyzer.get_state() |> IO.inspect()
  end



  def conf() do
    %{
      sync_interval: Application.get_env(:crdt_comparison, :sync_interval, @sync_interval),
      bp?: Application.get_env(:crdt_comparison, :bp?, @bp?)
    }
  end
end
