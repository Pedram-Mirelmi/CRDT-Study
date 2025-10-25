defmodule LinkLayer.ND_LinkLayer do
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

  def propagate(name, msg, bp?) do
    BaseLinkLayer.propagate(name, msg, bp?)
  end

  def handle_propagate(state, {:remote_sync, crdts_deltas}, bp?) do
    if bp? do
      Enum.each(state.neighbours, fn neighbour ->
        to_send =
          Enum.reduce(crdts_deltas, %{}, fn {key, delta_array}, acc ->
            to_send_array =
              Enum.filter(delta_array, fn {_delta, origin} ->
                origin != neighbour
              end)
            Map.put(acc, key, to_send_array)
          end)

        BaseLinkLayer.record_network_traffic(state, {:remote_sync, to_send}, :out)
        deliver(neighbour, {:remote_sync, to_send})
      end)
    else
      Enum.each(state.neighbours, fn neighbour ->
        # Logger.debug("ll #{inspect(name)} propagating to #{inspect(neighbour)}: #{inspect(msg)}")
        BaseLinkLayer.record_network_traffic(state, {:remote_sync, crdts_deltas}, :out)
        deliver(neighbour, {:remote_sync, crdts_deltas})
      end)
    end
    state
  end

end
