defmodule SB.SB_DB do
  alias Crdts.CRDT
  alias SB.SB_DB
  defstruct crdts: %{},
    updated_crdts: MapSet.new()


  def new() do
    %SB_DB{}
  end

  def merge(%SB_DB{crdts: crdts1, updated_crdts: updated_crdts1}, %SB_DB{crdts: crdts2, updated_crdts: updated_crdts2}) do
    new_crdts = Map.merge(crdts1, crdts2, fn key, v1, v2 ->
      {_key_bin, crdt_type} = key
      CRDT.affect(crdt_type, v1, v2)
    end)
    new_updated_crdts = MapSet.union(updated_crdts1, updated_crdts2)
    %SB_DB{crdts: new_crdts, updated_crdts: new_updated_crdts}
  end

  def apply_local_update(%SB_DB{crdts: crdts, updated_crdts: updated_crdts} = this, {_key_bin, crdt_type} = key, update) do
    crdt = Map.get(crdts, key, crdt_type.new())
    effect = CRDT.downstream_effect(crdt_type, crdt, update)
    new_crdt = CRDT.affect(crdt_type, crdt, effect)
    new_updated_crdts = MapSet.put(updated_crdts, key)
    %SB_DB{this | crdts: Map.put(crdts, key, new_crdt), updated_crdts: new_updated_crdts}
  end

  def apply_remote_effects(%SB_DB{crdts: crdts, updated_crdts: updated_crdts} = this, remote_effects) do
    # TODO optimize the loops into one

    new_crdts = Map.merge(crdts, remote_effects, fn key, local_v, remote_v ->
      {_key_bin, crdt_type} = key
      CRDT.affect(crdt_type, local_v, remote_v)
    end)

    new_updated_crdts = Enum.filter(remote_effects, fn {key, remote_effect} ->
      {_key_bin, crdt_type} = key
      local_crdt = Map.get(crdts, key, CRDT.new(crdt_type))
      CRDT.causes_inflation?(crdt_type, local_crdt, remote_effect)
    end) |>
      Enum.reduce(updated_crdts, fn {key, _remote_effect}, acc ->
        MapSet.put(acc, key)
      end)

    %SB_DB{this | crdts: new_crdts, updated_crdts: new_updated_crdts}
  end

  def clear_updated_crdts(this) do
    %SB_DB{this | updated_crdts: MapSet.new()}
  end

end
