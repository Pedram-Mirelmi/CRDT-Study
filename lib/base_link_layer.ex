defmodule BaseLinkLayer do
  alias Analyzer.CrdtAnalyzer
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

  def stop(name) do
    GenServer.stop(atom_name(name))
  end

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  def get_state(name) do
    GenServer.call(atom_name(name), :get_state)
  end

  def reset_init_wall_clock_time(name) do
    GenServer.cast(atom_name(name), :reset_init_wall_clock_time)
  end

  def connect(node1, node2) do
    :ok = add_neighbour(node1, node2)
    :ok = add_neighbour(node2, node1)
  end

  def disconnect(node1, node2) do
    :ok = remove_neighbour(node1, node2)
    :ok = remove_neighbour(node2, node1)
  end

  defp add_neighbour(name, neighbour) do
    :ok = GenServer.call(atom_name(name), {:add_neighbour, neighbour})
  end

  defp remove_neighbour(name, neighbour) do
    :ok = GenServer.call(atom_name(name), {:remove_neighbour, neighbour})
  end

  def deliver(sender_state, to, msg) do
    record_network_traffic(sender_state, msg, :out)
    GenServer.cast(atom_name(to), {:deliver, msg})
  end

  def record_network_traffic(state, network_msg, traffic_type) do
    now_wall_clock_time = :erlang.statistics(:wall_clock) |> elem(0)
    replica_time_stamp = now_wall_clock_time - state.init_wall_clock_time
    CrdtAnalyzer.record_network_traffic(state.name, replica_time_stamp, network_msg, traffic_type)
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:add_neighbour, neighbour}, _from, %{neighbours: neighbours} = state) do
    if neighbours == MapSet.new() do
      # Logger.debug("#{state.name} adding first neighbour: #{neighbour}")
      BaseNode.do_peer_full_sync(state.name, neighbour)
    end
    {:reply, :ok, %{state | neighbours: MapSet.put(state.neighbours, neighbour)}}
  end

  @impl true
  def handle_call({:remove_neighbour, neighbour}, _from, %{neighbours: neighbours} = state) do
    {:reply, :ok, %{state | neighbours: MapSet.delete(neighbours, neighbour)}}
  end


  @impl true
  def handle_call(request, from, state) do
    Logger.warning("Unhandled call request to #{inspect(state.name)}: #{inspect(request)} from #{inspect(from)}")
    {:reply, :ok, state}
  end

  def propagate(name, msg, conf) do
    GenServer.cast(atom_name(name), {:propagate, msg, conf})
  end

  def send_to_node(from, to, msg) do
    GenServer.cast(atom_name(from), {:send_to_node, to, msg})
  end

  def subscribe(name, subscription, topic) do
    GenServer.cast(atom_name(name), {:subscribe, subscription, topic})
  end

  @impl true
  def handle_cast(:reset_init_wall_clock_time, state) do
    new_state = %{state | init_wall_clock_time: :erlang.statistics(:wall_clock) |> elem(0)}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:propagate, msg, conf}, state) do
    new_state = state.module.handle_propagate(state, msg, conf)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:send_to_node, to, msg}, state) do
    BaseLinkLayer.deliver(state, to, msg)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:deliver, msg}, state) do
    # Logger.debug("#{state.name} delivered #{inspect(msg)}")
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
