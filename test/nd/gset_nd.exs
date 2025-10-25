defmodule ND.GSet_ND do
  alias StudyCases.NaiveDelta
  alias Node.ND_Node
  alias Crdts.Set_GO_ND
  alias Utils.TestUtility
  alias Topologies.BinTree
  alias StudyCases.StateBased
  use ExUnit.Case

  @n_nodes 2
  @set_objects 1
  @set_elements 5
  @update_pause 50

  @sync_interval 50
  @bp? true

  test "test1" do
    {tree, n_nodes} = NaiveDelta.start(@n_nodes, %{topology: :tree}, conf())


    TestUtility.trigger_set_add_update(@n_nodes, @set_objects, Set_GO_ND, @set_elements, ND_Node, @update_pause)

    :timer.sleep(2000)

    CrdtAnalyzer.get_state() |> IO.inspect()
  end



  def conf() do
    %{
      sync_interval: @sync_interval,
      bp?: @bp?
    }
  end
end
