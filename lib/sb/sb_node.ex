defmodule Node.SB_Node do
  alias LinkLayer.SB_LinkLayer
  alias Crdts.CRDT
  use GenServer
  require Logger

  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

  defp initial_state(name, conf) do


    %{
      conf: conf,
      crdts: %{},
      updated_crdts: MapSet.new(),
      name: name
    }
  end

  def start_link(name, conf) do
    GenServer.start_link(
      __MODULE__,
      initial_state(name, conf),
      name: atom_name(name)
    )
  end

  def start(name, conf) do
    GenServer.start(
      __MODULE__,
      initial_state(name, conf),
      name: atom_name(name)
    )
  end

  def stop(name) do
    GenServer.stop(atom_name(name))
  end

  @impl true
  def init(%{name: name} = init_state) do
    # Logger.debug("node #{inspect(name)} inited!")
    {:ok, _pid} = SB_LinkLayer.start_link(name)
    SB_LinkLayer.subscribe(name, {:gen, atom_name(name)}, :ll_deliver)

    Process.send_after(self(), {:sync}, init_state.conf.sync_interval)

    {:ok, init_state}
  end

  def connect(name, other) do
    :ok = GenServer.call(atom_name(name), {:connect, other})
  end

  def update(name, key, update) do
    :ok = GenServer.cast(atom_name(name), {:update, key, update})
  end

  @impl true
  def handle_call({:connect, other}, _from, %{name: name} = state) do
    :ok = SB_LinkLayer.connect(name, other)
    {:reply, :ok, state}
  end



  @impl true
  def handle_cast({:update, {_key_bin, crdt_type} = key, update}, %{crdts: crdts, updated_crdts: updated_crdts} = state) do
    crdt = Map.get(crdts, key, crdt_type.new())
    effect = CRDT.downstream_effect(crdt_type, crdt, update)
    new_crdt = CRDT.affect(crdt_type, crdt, effect)
    new_updated_crdts = MapSet.put(updated_crdts, key)
    {:noreply, %{state | crdts: Map.put(crdts, key, new_crdt), updated_crdts: new_updated_crdts}}
  end

  @impl true
  def handle_cast({:ll_deliver, {:remote_sync, remote_effects}}, %{crdts: crdts, updated_crdts: updated_crdts} = state) do
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


    {:noreply, %{state | crdts: new_crdts, updated_crdts: new_updated_crdts}}
  end


  @impl true
  def handle_info({:sync}, %{conf: conf, crdts: crdts, updated_crdts: updated_crdts, name: name} = state) do
    # Logger.debug("node #{inspect(name)} syncing")
    if conf.sync_method == :full do
      SB_LinkLayer.propagate(name, {:remote_sync, crdts})
    else
      to_send = Map.take(crdts, updated_crdts |> Enum.to_list())
      if to_send != %{} do
        SB_LinkLayer.propagate(name, {:remote_sync, to_send})
      end
    end
    Process.send_after(self(), {:sync}, conf.sync_interval)
    {:noreply, %{state | updated_crdts: MapSet.new()}}
  end

  @impl true
  def handle_info(msg, %{name: name} = state) do
    Logger.warning("Unhandled info msg to #{inspect(name)}: #{inspect(msg)}")
    {:noreply, state}
  end

end
