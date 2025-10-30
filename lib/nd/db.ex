defmodule ND.ND_DB do
  alias Crdts.CRDT
  alias ND.ND_DB
  defstruct crdts: %{}

  def new() do
    %ND_DB{}
  end

  def merge(%ND_DB{crdts: crdts1}, %ND_DB{crdts: crdts2}) do
    new_crdts = Map.merge(crdts1, crdts2, fn key, v1, v2 ->
      {_key_bin, crdt_type} = key
      CRDT.affect(crdt_type, v1, v2)
    end)
    %ND_DB{crdts: new_crdts}
  end

  def get_crdt(db, {_key_bin, crdt_type} = key) do
    crdt = Map.get(db.crdts, key, crdt_type.new())
    {crdt_type, crdt}
  end

  def apply_deltas(%ND_DB{crdts: crdts} = this, remote_crdts_delta) do
    {updated_crdts, effective_crdts_deltas} =
      Enum.reduce(remote_crdts_delta, {%{}, %{}}, fn {{_key_bin, crdt_type} = key, crdt_delta}, {acc_updated_crdts, acc_effective_crdts_deltas} ->
        local_crdt = Map.get(crdts, key, crdt_type.new())
        if CRDT.causes_inflation?(crdt_type, local_crdt, crdt_delta) do
          updated_crdt = crdt_type.affect(local_crdt, crdt_delta)
          new_acc_updated_crdts = Map.put(acc_updated_crdts, key, updated_crdt)
          new_acc_effective_crdts_deltas = Map.put(acc_effective_crdts_deltas, key, crdt_delta)
          {new_acc_updated_crdts, new_acc_effective_crdts_deltas}
        else
          {acc_updated_crdts, acc_effective_crdts_deltas}
        end
      end)
      {%ND_DB{this | crdts: Map.merge(crdts, updated_crdts)}, effective_crdts_deltas}
  end

end
