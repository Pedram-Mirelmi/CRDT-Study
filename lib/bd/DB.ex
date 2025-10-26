defmodule BD.BD_DB do
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
    {update_fun, update_args} = update
    effect = crdt_type.downstream_effect(local_crdt, {update_fun, update_args ++ [this.replica_name]})
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


  def compute_delta_from_crdt_vcs(this, crdts_vcs) do
    Enum.reduce(crdts_vcs, %{}, fn {{_key_bin, crdt_type} = key, crdt_vc}, acc_deltas ->
      {_crdt_type, local_crdt} = get_crdt(this, key)
      delta = crdt_type.get_delta(local_crdt, crdt_vc)
      if Kernel.map_size(delta.elements) > 0 do
        Map.put(acc_deltas, key, delta)
      else
        acc_deltas
      end
    end)
  end

  def get_strictly_older_crdt_vcs(this, crdts_vcs) do
    Enum.reduce(crdts_vcs, %{}, fn {key, crdt_vc}, acc_vcs ->
      {_crdt_type, local_crdt} = get_crdt(this, key)
      if VectorClock.leq(local_crdt.vc, crdt_vc) do
        Map.put(acc_vcs, key, local_crdt.vc)
      else
        acc_vcs
      end

    end)
  end

end
