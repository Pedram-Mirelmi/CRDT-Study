defmodule LinkLayer.SB_LinkLayer do
  alias Utility.SubHandler
  use GenServer
  require Logger

  def atom_name(node_name) do
    node_name <> "-ll" |> String.to_atom()
  end

  def initial_state(_name) do
    %{}
  end

  def start(name) do
    BaseLinkLayer.start(__MODULE__, name)
  end

  # @impl true
  # def init(init_arg) do
  #   # Logger.debug("ll #{inspect(init_arg.name)} inited!")
  #   {:ok, init_arg}
  # end

  # def stop(name) do
  #   GenServer.stop(atom_name(name))
  # end

  def subscribe(name, subscription, topic) do
    BaseLinkLayer.subscribe(name, subscription, topic)
  end

  def connect(replica1, replica2) do
    BaseLinkLayer.connect(replica1, replica2)
  end

  def deliver(name, msg) do
    BaseLinkLayer.deliver(name, msg)
  end


  # @impl true
  # def handle_call({:add_neighbour, neighbour}, _from, %{neighbours: neighbours} = state) do
  #   {:reply, :ok, %{state | neighbours: MapSet.put(neighbours, neighbour)}}
  # end

  def propagate(name, msg) do
    BaseLinkLayer.propagate(name, msg, Keyword.new())
  end

  # @spec subscribe(binary(), SubHandler.subscription(), SubHandler.topic()) :: :ok
  # def subscribe(name, subscription, topic) do
  #   GenServer.cast(atom_name(name), {:subscribe, subscription, topic})
  # end

  def handle_propagate(state, msg, _conf) do
    Enum.each(state.neighbours, fn neighbour ->
      # Logger.debug("ll #{inspect(name)} propagating to #{inspect(neighbour)}: #{inspect(msg)}")
      BaseLinkLayer.record_network_traffic(state, msg, :out)
      deliver(neighbour, msg)
    end)
    state
  end

  # @impl true
  # def handle_cast({:propagate, msg}, %{neighbours: neighbours, name: name} = state) do
  #   Enum.each(neighbours, fn neighbour ->
  #     # Logger.debug("ll #{inspect(name)} propagating to #{inspect(neighbour)}: #{inspect(msg)}")
  #     CrdtAnalyzer.record_outgoing_traffic(name, msg)
  #     deliver(neighbour, msg)
  #   end)
  #   {:noreply, state}
  # end

  # @impl true
  # def handle_cast({:deliver, msg}, %{sub_handler: sub_handler} = state) do
  #   CrdtAnalyzer.record_incomming_traffic(state.name, msg)
  #   SubHandler.publish(sub_handler, :ll_deliver, msg)
  #   {:noreply, state}
  # end

  # @impl true
  # def handle_cast({:subscribe, subscription, topic}, %{sub_handler: %SubHandler{} = sub_handler} = state) do
  #   new_sub_handler = SubHandler.add_subscription(sub_handler, subscription, topic)
  #   {:noreply, %{state | sub_handler: new_sub_handler}}
  # end


end
