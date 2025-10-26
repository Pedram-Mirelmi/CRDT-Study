defmodule LinkLayer.ND_LinkLayer do
  alias ND.ND_Buffer
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

  def handle_propagate(state, {:remote_sync, %ND_Buffer{crdts_deltas: crdts_deltas}}, bp?) do
    if bp? do
      Enum.each(state.neighbours, fn neighbour ->
        bp_optimized_crdts_deltas =
          Enum.reduce(crdts_deltas, %{}, fn {key, origin_delta_map}, acc ->
            single_crdt_bp_optimized = Map.delete(origin_delta_map, neighbour)
            Map.put(acc, key, single_crdt_bp_optimized)
          end)
        Logger.debug("on node #{inspect(state.name)} bp_optimized_crdts_deltas: #{inspect(bp_optimized_crdts_deltas)} while deltas: #{inspect(crdts_deltas)}")
        BaseLinkLayer.record_network_traffic(state, {:remote_sync, bp_optimized_crdts_deltas}, :out)
        deliver(neighbour, {:remote_sync, %ND_Buffer{crdts_deltas: bp_optimized_crdts_deltas}})
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
