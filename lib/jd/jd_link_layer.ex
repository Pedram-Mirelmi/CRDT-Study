defmodule JD.JD_LinkLayer do
  alias JD.JD_Buffer
  require Logger

  def initial_state(_name) do
    %{}
  end

  def handle_propagate(state, {:remote_sync, delta_buffer}, bp?) do
    Enum.each(state.neighbours, fn neighbour ->
      if bp? do
        all_crdts_bp_optimized_delta_groups = JD_Buffer.remove_origin(delta_buffer, neighbour)

        BaseLinkLayer.record_network_traffic(state, {:remote_sync, all_crdts_bp_optimized_delta_groups}, :out)
        BaseLinkLayer.deliver(neighbour, {:remote_sync, all_crdts_bp_optimized_delta_groups})
      else
        Enum.each(state.neighbours, fn neighbour ->
          # Logger.debug("ll #{inspect(name)} propagating to #{inspect(neighbour)}: #{inspect(msg)}")
          BaseLinkLayer.record_network_traffic(state, {:remote_sync, delta_buffer}, :out)
          BaseLinkLayer.deliver(neighbour, {:remote_sync, delta_buffer})
        end)
      end
    end)
    state
  end
end
