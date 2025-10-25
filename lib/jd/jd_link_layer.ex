defmodule JD.JD_LinkLayer do
  alias JD.Buffer
  alias Utility.SubHandler
  use GenServer
  require Logger

  def atom_name(node_name) do
    node_name <> "-ll" |> String.to_atom()
  end

  defp initial_state(name) do
    %{
      neighbours: MapSet.new(),
      sub_handler: SubHandler.new(),
      name: name
    }
  end

  def start_link(name) do
    # Logger.debug("ll started link")
    GenServer.start_link(
      __MODULE__,
      initial_state(name),
      name: atom_name(name)
    )
  end

  def start(name) do
    GenServer.start(
      __MODULE__,
      initial_state(name),
      name: atom_name(name)
    )
  end

  @impl true
  def init(init_arg) do
    # Logger.debug("ll #{inspect(init_arg.name)} inited!")
    {:ok, init_arg}
  end

  def stop(name) do
    GenServer.stop(atom_name(name))
  end

  def connect(node1, node2) do
    :ok = add_neighbour(node1, node2)
    :ok = add_neighbour(node2, node1)
  end

  defp add_neighbour(this_node, neighbour) do
    :ok = GenServer.call(atom_name(this_node), {:add_neighbour, neighbour})
  end

  def deliver(name, msg) do
    GenServer.cast(atom_name(name), {:deliver, msg})
  end


  @impl true
  def handle_call({:add_neighbour, neighbour}, _from, %{neighbours: neighbours} = state) do
    {:reply, :ok, %{state | neighbours: MapSet.put(neighbours, neighbour)}}
  end


  @impl true
  def handle_call(request, _from, %{name: name} = state) do
    Logger.warning("Unhandled call request to #{inspect(name)}: #{inspect(request)}")
    {:noreply, state}
  end

  @impl true
  def handle_call(request, from, state) do
    Logger.warning("Unhandled call request to #{inspect(state.name)}: #{inspect(request)} from #{inspect(from)}")
    {:reply, :ok, state}
  end

  def propagate(name, msg, bp?) do
    GenServer.cast(atom_name(name), {:propagate, msg, bp?})
  end

  @spec subscribe(binary(), SubHandler.subscription(), SubHandler.topic()) :: :ok
  def subscribe(name, subscription, topic) do
    GenServer.cast(atom_name(name), {:subscribe, subscription, topic})
  end

  @impl true
  def handle_cast({:propagate, {:remote_sync, delta_buffer}, bp?}, %{neighbours: neighbours} = state) do
    Enum.each(neighbours, fn neighbour ->
      if bp? do
        all_crdts_bp_optimized_delta_groups = Buffer.remove_origin(delta_buffer, neighbour)

        CrdtAnalyzer.record_outgoing_traffic(state.name, {:remote_sync, all_crdts_bp_optimized_delta_groups})
        deliver(neighbour, {:remote_sync, all_crdts_bp_optimized_delta_groups})
      else
        Enum.each(neighbours, fn neighbour ->
          # Logger.debug("ll #{inspect(name)} propagating to #{inspect(neighbour)}: #{inspect(msg)}")
          CrdtAnalyzer.record_outgoing_traffic(state.name, {:remote_sync, delta_buffer})
          deliver(neighbour, {:remote_sync, delta_buffer})
        end)
      end

    end)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:deliver, msg}, %{sub_handler: sub_handler} = state) do
    CrdtAnalyzer.record_incomming_traffic(state.name, msg)
    SubHandler.publish(sub_handler, :ll_deliver, msg)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:subscribe, subscription, topic}, %{sub_handler: %SubHandler{} = sub_handler} = state) do
    new_sub_handler = SubHandler.add_subscription(sub_handler, subscription, topic)
    {:noreply, %{state | sub_handler: new_sub_handler}}
  end

  @impl true
  def handle_cast(request, state) do
    Logger.warning("Unhandled cast request to #{inspect(state.name)}: #{inspect(request)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unhandled info msg to #{inspect(state.name)}: #{inspect(msg)}")
    {:noreply, state}
  end

end
