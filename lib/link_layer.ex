defmodule LinkLayer do
  alias Utility.SubHandler
  use GenServer
  require Logger

  defp initial_state(name) do
    %{
      neighbours: MapSet.new(),
      sub_handler: SubHandler.new(),
      name: name
    }
  end

  def start_link(name) do
    GenServer.start_link(
      __MODULE__,
      initial_state(name),
      name: name
    )
  end

  def start(name) do
    GenServer.start(
      __MODULE__,
      initial_state(name),
      name: name
    )
  end

  def stop(name) do
    GenServer.stop(name)
  end

  def connect(node1, node2) do
    add_neighbour(node1, node2)
    add_neighbour(node2, node1)
  end

  defp add_neighbour(this_node, neighbour) do
    :ok = GenServer.call(this_node, {:add_neighbour, neighbour})
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

  def propagate(name, msg, except_these) do
    GenServer.cast(name, {:propagate, msg, except_these})
  end

  def deliver(name, msg) do
    GenServer.cast(name, {:deliver, msg})
  end

  @impl true
  def handle_cast({:propagate, msg, except_these}, %{neighbours: neighbours} = state) do
    neighbours
      |> MapSet.difference(except_these |> MapSet.new())
      |> Enum.each(&(deliver(&1, msg)))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:deliver, msg}, state) do

    # TODO handle the

    {:noreply, state}
  end


end
