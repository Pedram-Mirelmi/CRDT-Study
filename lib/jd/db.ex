defmodule JD.JD_DB do
  alias JD.JD_DB
  alias Crdts.CRDT
  defstruct crdts: %{}



  def new() do
    %JD_DB{}
  end

  def get_crdt(db, {_key_bin, crdt_type} = key) do
    crdt = Map.get(db.crdts, key, CRDT.new(crdt_type))
    {crdt_type, crdt}
  end


  def apply_deltas(%JD_DB{crdts: crdts} = this, remote_crdts_delta) do
    {updated_crdts, effective_crdts_deltas} =
      Enum.reduce(remote_crdts_delta, {%{}, %{}}, fn {{_key_bin, crdt_type} = key, crdt_delta_jds}, {acc_updated_crdts, acc_effective_crdts_deltas} ->
        local_crdt = Map.get(crdts, key, crdt_type.new())
        strictly_inflating_jds = MapSet.filter(crdt_delta_jds, fn delta ->
          CRDT.causes_inflation?(crdt_type, local_crdt, delta)
        end)
        if MapSet.size(strictly_inflating_jds) != 0 do
          updated_local_crdt = crdt_type.merge_states([local_crdt | MapSet.to_list(strictly_inflating_jds)])
          new_acc_updated_crdts = Map.put(acc_updated_crdts, key, updated_local_crdt)
          new_acc_effective_crdts_deltas = Map.put(acc_effective_crdts_deltas, key, strictly_inflating_jds)
          {new_acc_updated_crdts, new_acc_effective_crdts_deltas}
        else
          {acc_updated_crdts, acc_effective_crdts_deltas}
        end
      end)
      {%JD_DB{this | crdts: Map.merge(crdts, updated_crdts)}, effective_crdts_deltas}
  end

end
