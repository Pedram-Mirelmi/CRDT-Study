defmodule BD.BD_LinkLayer do
  require Logger

  def initial_state(_name) do
    %{}
  end

  def start_link(name) do
    BaseLinkLayer.start_link(__MODULE__, name)
  end

  def subscribe(name, subscription, topic) do
    BaseLinkLayer.subscribe(name, subscription, topic)
  end

  def connect(replica1, replica2) do
    BaseLinkLayer.connect(replica1, replica2)
  end

  def deliver(name, msg) do
    BaseLinkLayer.deliver(name, msg)
  end

  def propagate(name, msg, conf) do
    BaseLinkLayer.propagate(name, msg, conf)
  end

  def send_to_replica(from, to, msg, conf) do

    BaseLinkLayer.send_to_replica(from, to, msg, conf)
  end

  def handle_propagate(state, msg, bd_sync_method) do
    case bd_sync_method do
      :all ->
        Enum.each(state.neighbours, fn neighbour ->
          BaseLinkLayer.record_network_traffic(state, msg, :out)
          deliver(neighbour, msg)
        end)
      :random ->
        neighbour = state.neighbours |> Enum.random()
        BaseLinkLayer.record_network_traffic(state, msg, :out)
        deliver(neighbour, msg)
      other ->
        Logger.warning("Unknown sync method #{inspect(other)} in BD_LinkLayer")

    end
    state
  end
end
