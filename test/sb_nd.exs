defmodule CrdtComparisonTest do
  alias Crdts.Set_GO_ND
  alias Crdts.Set_GO_SB
  alias BD.BD_Node
  alias ND.ND_Node
  alias SB.SB_Node
  alias JD.JD_Node
  use ExUnit.Case
  doctest CrdtComparison

  test "Simple dimand topology" do
    cases = %{
      SB_Node => [{:set, Set_GO_SB}],
      ND_Node => [{:set, Set_GO_ND}],
      JD_Node => [{:set, Set_GO_JD}],
      BD_Node => [{:set, Set_GO_BD}]
    }

    for {node_module, crdt_list} <- cases do
      for {crdt_type, crdt_module} <- crdt_list do

      end
    end

  end

  test "Naive-Delta advantage in simple scenarios" do


  end




end
