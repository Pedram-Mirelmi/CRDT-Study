defmodule LinkLayer.SB_LinkLayer do
  require Logger

  def initial_state(_name) do
    %{}
  end

  def start(name) do
    BaseLinkLayer.start(__MODULE__, name)
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

  def propagate(name, msg) do
    BaseLinkLayer.propagate(name, msg, nil)
  end


  def handle_propagate(state, msg, _conf) do
    Enum.each(state.neighbours, fn neighbour ->
      # Logger.debug("ll #{inspect(name)} propagating to #{inspect(neighbour)}: #{inspect(msg)}")
      BaseLinkLayer.record_network_traffic(state, msg, :out)
      deliver(neighbour, msg)
    end)
    state
  end

end
