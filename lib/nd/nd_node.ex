defmodule Node.ND_Node do
  alias LinkLayer.ND_LinkLayer
  alias Crdts.CRDT
  @behaviour BaseNode
  require Logger

  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

  @impl true
  def ll_module() do
    ND_LinkLayer
  end

  @impl true
  def initial_state(name, conf) do
    %{
      conf: conf,
      crdts: %{},
      buffer: %{},
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

  defp store(deltas_map, buffer, crdts, %{bp?: bp?}) do
    Logger.debug("Storing in node #{inspect(self())}: #{inspect(deltas_map)}")
    if bp? do
      Enum.reduce(deltas_map, {crdts, buffer}, fn {{_key_bin, crdt_type} = key, delta_array}, {acc_crdts, acc_buffer} ->
        local_crdt = Map.get(acc_crdts, key, CRDT.new(crdt_type))
        updated_crdt = Enum.reduce(delta_array, local_crdt, fn {delta, _origin}, acc_crdt ->
          crdt_type.merge_state(acc_crdt, delta)
        end)
        new_crdts = Map.put(acc_crdts, key, updated_crdt)
        ##########
        local_delta_array = Map.get(acc_buffer, key, [])
        new_buffer = Map.put(acc_buffer, key, delta_array ++ local_delta_array)
        Logger.debug("Storing in node #{inspect(self())} in buffer for #{inspect(key)}: #{inspect(new_buffer)}")
        {new_crdts, new_buffer}
      end)
    else
      Enum.reduce(deltas_map, {crdts, buffer}, fn {{_key_bin, crdt_type} = key, delta}, {acc_crdts, acc_buffer} ->
        local_crdt = Map.get(acc_crdts, key, CRDT.new(crdt_type))
        updated_crdt = crdt_type.merge_state(local_crdt, delta)
        new_crdts = Map.put(acc_crdts, key, updated_crdt)
        ##########
        local_delta = Map.get(acc_buffer, key, crdt_type.empty_state())
        new_buffer = Map.put(acc_buffer, key, crdt_type.merge_deltas(local_delta, delta))

        {new_crdts, new_buffer}
      end)
    end
  end


  @impl true
  def handle_update(state, key, update) do
    # Logger.debug("node #{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    {crdt_type, crdt} = get_crdt_info(key, state.crdts)
    delta = CRDT.downstream_effect(crdt_type, crdt, update)
    {new_crdts, new_buffer} =
      if state.conf.bp? do
        store(%{key => [{delta, state.name}]}, state.buffer, state.crdts, state.conf)
      else
        store(%{key => delta}, state.buffer, state.crdts, state.conf)
      end
    %{state | crdts: new_crdts, buffer: new_buffer}
  end

  @impl true
  def handle_ll_deliver(state, {:remote_sync, remote_effects}) do
    affecting_effects =
      Enum.filter(remote_effects, fn {{_key_bin, crdt_type} = key, crdt_delta} ->
        local_crdt = Map.get(state.crdts, key, CRDT.new(crdt_type))

        if state.conf.bp? do
          Enum.any?(crdt_delta, fn {delta, _origin} ->
            CRDT.causes_inflation?(crdt_type, local_crdt, delta)
          end)
        else
          CRDT.causes_inflation?(crdt_type, local_crdt, crdt_delta)
        end

      end) |>
        Enum.into(%{})

    {new_crdts, new_buffer} = store(affecting_effects, state.buffer, state.crdts, state.conf)

    %{state | crdts: new_crdts, buffer: new_buffer}
  end

  @impl true
  def handle_periodic_sync(state) do
    # Logger.debug("node #{inspect(state.name)} syncing")
    ND_LinkLayer.propagate(state.name, {:remote_sync, state.buffer}, bp?: state.conf.bp?)
    %{state | buffer: MapSet.new()}
  end

  defp get_crdt_info({_key_bin, crdt_type} = key, crdts) do
    crdt = Map.get(crdts, key, CRDT.new(crdt_type))
    {crdt_type, crdt}
  end

end
