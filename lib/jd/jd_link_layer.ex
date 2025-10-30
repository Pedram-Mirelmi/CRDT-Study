defmodule JD.JD_LinkLayer do
  alias JD.JD_Buffer
  require Logger

  def initial_state(_name) do
    %{}
  end

  def handle_propagate(state, {:remote_sync, delta_buffer}, bp?) do
    Enum.each(state.neighbours, fn neighbour ->
      if bp? do
        all_crdts_bp_optimized_delta_groups = JD_Buffer.remove_jds_from_origin(delta_buffer, neighbour)
        BaseLinkLayer.deliver(state, neighbour, {:remote_sync, all_crdts_bp_optimized_delta_groups, state.name})
      else
        Enum.each(state.neighbours, fn neighbour ->
          BaseLinkLayer.deliver(state, neighbour, {:remote_sync, delta_buffer.crdts_deltas})
        end)
      end
    end)
    state
  end
end
