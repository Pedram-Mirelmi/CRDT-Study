defmodule BD.BD_DB do
  require Logger
  alias Utility.VectorClock
  alias Crdts.CRDT
  alias BD.BD_DB
  defstruct crdts: %{}, replica_name: nil


  def new(replica_name) do
    %BD_DB{replica_name: replica_name}
  end


  def get_crdt(db, {_key_bin, crdt_type} = key) do
    crdt = Map.get(db.crdts, key, CRDT.new(crdt_type))
    {crdt_type, crdt}
  end

  def get_all_vcs(%BD_DB{crdts: crdts}) do
    Enum.reduce(crdts, %{}, fn {key, crdt}, acc_vcs ->
      Map.put(acc_vcs, key, crdt.vc)
    end)
  end

  def apply_local_update(this, key, update) do
    {crdt_type, local_crdt} = get_crdt(this, key)
    effect = crdt_type.downstream_effect(local_crdt, update)
    updated_crdt = crdt_type.affect(local_crdt, effect)
    %BD_DB{this | crdts: Map.put(this.crdts, key, updated_crdt)}
  end

  def apply_deltas(this, crdts_deltas) do
    new_crdts =
      Enum.reduce(crdts_deltas, this.crdts, fn {{_key_bin, crdt_type} = key, crdt_delta}, acc_crdts ->
        local_crdt = Map.get(acc_crdts, key, CRDT.new(crdt_type))
        updated_crdt = crdt_type.affect(local_crdt, crdt_delta)
        Map.put(acc_crdts, key, updated_crdt)
      end)
    %BD_DB{this | crdts: new_crdts}
  end


  def compute_delta_from_crdt_vcs(this, remote_crdts_vcs) do
    local_crdt_keys = this.crdts |> Map.keys() |> MapSet.new()
    remote_keys = remote_crdts_vcs |> Map.keys() |> MapSet.new()
    all_keys = MapSet.union(local_crdt_keys, remote_keys)
    Enum.reduce(all_keys, %{}, fn key, acc_deltas ->
      remote_crdt_vc = Map.get(remote_crdts_vcs, key, VectorClock.new())
      {crdt_type, local_crdt} = get_crdt(this, key)
      computed_delta = crdt_type.get_delta(local_crdt, remote_crdt_vc)
      if computed_delta != crdt_type.empty_state() do
        # Logger.warning("non-empty computed_delta between me: #{inspect(local_crdt)} and vc: #{inspect(crdt_vc)}")
        Map.put(acc_deltas, key, computed_delta)
      else
        acc_deltas
      end
    end)
  end

  def get_strictly_older_crdt_vcs(this, crdts_vcs) do
    Enum.reduce(crdts_vcs, %{}, fn {key, crdt_vc}, acc_vcs ->
      {_crdt_type, local_crdt} = get_crdt(this, key)
      if VectorClock.lt(local_crdt.vc, crdt_vc) do
        Map.put(acc_vcs, key, local_crdt.vc)
      else
        acc_vcs
      end

    end)
  end

end
