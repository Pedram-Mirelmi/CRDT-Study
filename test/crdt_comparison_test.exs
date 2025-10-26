defmodule Test.CrdtComparison do
  alias Analyzer.CrdtAnalyzer
  alias Crdts.Set_GO_BD
  alias Crdts.Set_GO_JD
  alias Crdts.Set_GO_ND
  alias Crdts.Set_GO_SB
  alias Utils.TestUtility
  alias BD.BD_Node
  alias JD.JD_Node
  alias ND.ND_Node
  alias SB.SB_Node
  use ExUnit.Case

  @repititions 2

  @node0 "node0"
  @node1 "node1"
  @node2 "node2"
  @node3 "node3"
  @node4 "node4"


  def nodes_cases() do
    %{
      # SB_Node => [{:set, Set_GO_SB}],
      # ND_Node => [{:set, Set_GO_ND}],
      JD_Node => [{:set, Set_GO_JD}],
      # BD_Node => [{:set, Set_GO_BD}]
    }
  end


  @tag timeout: :infinity
  test "Simple pair test" do
    Enum.each(nodes_cases(), fn {node_module, crdt_cases} ->
      node_conf = node_module.default_conf() |> Map.put(:sync_interval, 2000000)
      TestUtility.form_simple_pair(node_module, node_conf)
      Enum.each(crdt_cases, fn {crdt_data_type, crdt_module} ->
        key = {"key", crdt_module}
        nodes = {@node0, @node1}
        for i <- 0..(2*@repititions-1) do
          target_node_name = elem(nodes, rem(i, 2))
          update = TestUtility.sample_update(crdt_data_type, i)
          BaseNode.update(target_node_name, key, update)
          BaseNode.sync_now(target_node_name)
          :timer.sleep(50)
        end

        :timer.sleep(500)
        # :timer.sleep(50000000000)

        nodes_states = TestUtility.get_nodes_crdts(2)
        TestUtility.assert_states_equal(nodes_states)
        TestUtility.save_metrices(node_module, crdt_module)
        # reset analyzer
        CrdtAnalyzer.reset()
        # reset nodes states
        TestUtility.reset_nodes_states(2)
      end)

      TestUtility.stop_n_nodes(2)
    end)
  end

end
