defmodule SB.DB do
  alias Crdts.CRDT
  alias SB.DB
  defstruct crdts: %{},
    updated_crdts: MapSet.new()


  def new() do
    %DB{}
  end

  def apply_local_update(%DB{crdts: crdts, updated_crdts: updated_crdts} = this, {_key_bin, crdt_type} = key, update) do
    crdt = Map.get(crdts, key, crdt_type.new())
    effect = CRDT.downstream_effect(crdt_type, crdt, update)
    new_crdt = CRDT.affect(crdt_type, crdt, effect)
    new_updated_crdts = MapSet.put(updated_crdts, key)
    %DB{this | crdts: Map.put(crdts, key, new_crdt), updated_crdts: new_updated_crdts}
  end

  def apply_remote_effects(%DB{crdts: crdts, updated_crdts: updated_crdts} = this, remote_effects) do
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

    %DB{this | crdts: new_crdts, updated_crdts: new_updated_crdts}
  end

  def clear_updated_crdts(this) do
    %DB{this | updated_crdts: MapSet.new()}
  end

end
