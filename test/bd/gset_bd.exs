defmodule BD.GSet_BD do
  alias BD.BigDelta
  alias BD.BD_Node
  alias Crdts.Set_GO_BD
  alias Utils.SimulationUtility
  alias Topologies.BinTree
  use ExUnit.Case

  @n_nodes 2
  @set_objects 1
  @set_elements 20


  @update_pause 40

  @sync_interval 150
  @sync_method :random # :all, :random

  test "test1" do
    {tree, n_nodes} = BigDelta.start(@n_nodes, %{topology: :tree}, conf())


    SimulationUtility.trigger_set_add_update(@n_nodes, @set_objects, Set_GO_BD, @set_elements, BD_Node, @update_pause)

    :timer.sleep(2000)

    states = SimulationUtility.get_nodes_crdts(@n_nodes, BD_Node)
    IO.inspect(states)

    CrdtAnalyzer.get_state() |> IO.inspect()
  end



  def conf() do
    %{
      sync_interval: Application.get_env(:crdt_comparison, :sync_interval, @sync_interval),
      bd_sync_method: Application.get_env(:crdt_comparison, :bd_sync_method, @sync_method)
    }
  end
end
