defmodule BaseLinkLayer do
  alias Utility.SubHandler
  require Logger
  use GenServer

  def atom_name(node_name) do
    node_name <> "-ll" |> String.to_atom()
  end


  defp base_initial_state(name) do
    %{
      neighbours: MapSet.new(),
      sub_handler: Utility.SubHandler.new(),
      name: name,
      init_wall_clock_time: :erlang.statistics(:wall_clock) |> elem(0)
    }
  end

  defp initial_state(name, module) do
    base_state = base_initial_state(name)
    module_state = module.initial_state(name)
    base_state |> Map.merge(module_state) |> Map.put(:module, module)
  end

  def start_link(module, name) do

    GenServer.start_link(
      __MODULE__,
      initial_state(name, module),
      name: atom_name(name)
    )
  end

  def start(module, name) do
    # Logger.debug("ll started link")
    GenServer.start(
      __MODULE__,
      initial_state(name, module),
      name: atom_name(name)
    )
  end

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  def connect(node1, node2) do
    :ok = add_neighbour(node1, node2)
    :ok = add_neighbour(node2, node1)
  end

  defp add_neighbour(name, neighbour) do
    :ok = GenServer.call(atom_name(name), {:add_neighbour, neighbour})
  end

  def deliver(name, msg) do
    GenServer.cast(atom_name(name), {:deliver, msg})
  end

  def record_network_traffic(state, network_msg, traffic_type) do
    now_wall_clock_time = :erlang.statistics(:wall_clock) |> elem(0)
    replica_time_stamp = now_wall_clock_time - state.init_wall_clock_time
    CrdtAnalyzer.record_network_traffic(state.name, replica_time_stamp, network_msg, traffic_type)
  end

   @impl true
  def handle_call({:add_neighbour, neighbour}, _from, state) do
    {:reply, :ok, %{state | neighbours: MapSet.put(state.neighbours, neighbour)}}
  end


  @impl true
  def handle_call(request, from, state) do
    Logger.warning("Unhandled call request to #{inspect(state.name)}: #{inspect(request)} from #{inspect(from)}")
    {:reply, :ok, state}
  end

  def propagate(name, msg, conf) do
    GenServer.cast(atom_name(name), {:propagate, msg, conf})
  end

  def subscribe(name, subscription, topic) do
    GenServer.cast(atom_name(name), {:subscribe, subscription, topic})
  end

  @impl true
  def handle_cast({:propagate, msg, conf}, state) do
    new_state = state.module.handle_propagate(state, msg, conf)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:deliver, msg}, state) do
    SubHandler.publish(state.sub_handler, :ll_deliver, msg)
    record_network_traffic(state, msg, :in)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:subscribe, subscription, topic}, state) do
    new_sub_handler = SubHandler.add_subscription(state.sub_handler, subscription, topic)
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
