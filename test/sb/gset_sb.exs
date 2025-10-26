defmodule SB.GSet_SB do
  alias SB.SB_Node
  alias Crdts.Set_GO_SB
  alias Utils.TestUtility
  alias Topologies.BinTree
  alias StudyCases.StateBased
  use ExUnit.Case

  @n_nodes 2
  @set_objects 1
  @set_elements 20
  @update_pause 50

  @sync_interval 40
  @sync_method :updates_only # :full or :updates_only

  test "test1" do
    {tree, n_nodes} = StateBased.start(@n_nodes, %{topology: :tree}, conf())


    TestUtility.trigger_set_add_update(@n_nodes, @set_objects, Set_GO_SB, @set_elements, SB_Node, @update_pause)

    :timer.sleep(2000)

    CrdtAnalyzer.get_state() |> IO.inspect()
  end

  defp conf() do
    %{
      sync_interval: Application.get_env(:crdt_comparison, :sync_interval, @sync_interval),
      sb_sync_method: Application.get_env(:crdt_comparison, :sb_sync_method, @sync_method) # :full or :updates_only
    }
  end

end
