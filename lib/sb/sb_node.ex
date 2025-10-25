defmodule Node.SB_Node do
  alias LinkLayer.SB_LinkLayer
  alias Crdts.CRDT
  @behaviour BaseNode
  require Logger


  
  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

  def ll_module() do
    SB_LinkLayer
  end

  def initial_state(name, conf) do
    %{
      conf: conf,
      crdts: %{},
      updated_crdts: MapSet.new(),
      name: name
    }
  end

  def start_link(name, conf) do
    BaseNode.start_link(name, conf, __MODULE__)
  end

  def start(name, conf) do
    BaseNode.start(name, conf, __MODULE__)
  end

  def connect(name, other) do
    BaseNode.connect(name, other)
  end

  def update(name, key, update) do
    BaseNode.update(name, key, update)
  end

  def handle_update(%{crdts: crdts, updated_crdts: updated_crdts} = state, {_key_bin, crdt_type} = key, update) do
    crdt = Map.get(crdts, key, crdt_type.new())
    effect = CRDT.downstream_effect(crdt_type, crdt, update)
    new_crdt = CRDT.affect(crdt_type, crdt, effect)
    new_updated_crdts = MapSet.put(updated_crdts, key)
    %{state | crdts: Map.put(crdts, key, new_crdt), updated_crdts: new_updated_crdts}
  end

  def handle_ll_deliver(%{crdts: crdts, updated_crdts: updated_crdts} = state, {:remote_sync, remote_effects}) do
    # Logger.debug("node #{inspect(state.name)} received remote sync: #{inspect(remote_effects)}")
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

    %{state | crdts: new_crdts, updated_crdts: new_updated_crdts}
  end

  def handle_periodic_sync(%{conf: conf, crdts: crdts, name: name, updated_crdts: updated_crdts} = state) do
    # Logger.debug("node #{inspect(name)} syncing")
    if conf.sync_method == :full do
      SB_LinkLayer.propagate(name, {:remote_sync, crdts})
    else
      to_send = Map.take(crdts, updated_crdts |> Enum.to_list())
      if to_send != %{} do
        SB_LinkLayer.propagate(name, {:remote_sync, to_send})
      end
    end

    %{state | updated_crdts: MapSet.new()}
  end

end
