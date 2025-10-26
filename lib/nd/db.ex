defmodule ND.ND_DB do
  alias Crdts.CRDT
  alias ND.ND_Buffer
  alias ND.ND_DB
  defstruct crdts: %{}

  def new() do
    %ND_DB{}
  end

  def get_crdt(db, {_key_bin, crdt_type} = key) do
    crdt = Map.get(db.crdts, key, crdt_type.new())
    {crdt_type, crdt}
  end

  def apply_deltas(%ND_DB{crdts: crdts} = this, %ND_Buffer{crdts_deltas: remote_crdts_delta} = _remote_crdts_delta_buffer, bp?) do
    # extract effective deltas
    {updated_crdts, effective_crdts_deltas} =
      Enum.reduce(remote_crdts_delta, {%{}, %{}}, fn {{_key_bin, crdt_type} = key, crdt_delta}, {acc_updated_crdts, acc_effective_crdts_deltas} ->
        local_crdt = Map.get(crdts, key, crdt_type.new())
        {updated_crdt, effective_deltas} = update_single_crdt_with_delta(crdt_type, local_crdt, crdt_delta, bp?)

        if effective_deltas == %{} or effective_deltas == crdt_type.empty_state() do
          {acc_updated_crdts, acc_effective_crdts_deltas}
        else
          new_acc_updated_crdts = Map.put(acc_updated_crdts, key, updated_crdt)
          new_acc_effective_crdts = Map.put(acc_effective_crdts_deltas, key, effective_deltas)
          {new_acc_updated_crdts, new_acc_effective_crdts}
        end
      end)
    {%ND_DB{this | crdts: Map.merge(crdts, updated_crdts)}, %ND_Buffer{crdts_deltas: effective_crdts_deltas}}
  end


  # bp optimized
  defp update_single_crdt_with_delta(crdt_type, crdt, deltas, true) do
    Enum.reduce(deltas, {crdt, %{}}, fn {origin, single_delta}, {acc_crdt, acc_effective_deltas} ->
      if CRDT.causes_inflation?(crdt_type, acc_crdt, single_delta) do
        new_acc_crdt = crdt_type.affect(acc_crdt, single_delta)
        new_acc_effective_deltas = Map.put(acc_effective_deltas, origin, single_delta)
        {new_acc_crdt, new_acc_effective_deltas}
      else
        {acc_crdt, acc_effective_deltas}
      end
    end)
  end


  # not bp optimized
  defp update_single_crdt_with_delta(crdt_type, crdt, delta, false) do

  end

end
