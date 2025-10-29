defmodule JD.JD_LinkLayer do
  alias JD.JD_Buffer
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

  def handle_propagate(state, {:remote_sync, delta_buffer}, bp?) do
    Enum.each(state.neighbours, fn neighbour ->
      if bp? do
        all_crdts_bp_optimized_delta_groups = JD_Buffer.remove_origin(delta_buffer, neighbour)

        BaseLinkLayer.record_network_traffic(state, {:remote_sync, all_crdts_bp_optimized_delta_groups}, :out)
        deliver(neighbour, {:remote_sync, all_crdts_bp_optimized_delta_groups})
      else
        Enum.each(state.neighbours, fn neighbour ->
          # Logger.debug("ll #{inspect(name)} propagating to #{inspect(neighbour)}: #{inspect(msg)}")
          BaseLinkLayer.record_network_traffic(state, {:remote_sync, delta_buffer}, :out)
          deliver(neighbour, {:remote_sync, delta_buffer})
        end)
      end
    end)
    state
  end
end
