defmodule LinkLayer.ND_LinkLayer do
  alias ND.ND_Buffer
  require Logger

  def initial_state(_name) do
    %{}
  end

  def handle_propagate(state, {:remote_sync, full_buffer}, bp?) do
    if bp? do
      Enum.each(state.neighbours, fn neighbour ->
        to_send_buffer = ND_Buffer.remove_deltas_from_origin(full_buffer, neighbour)
        BaseLinkLayer.deliver(state, neighbour, {:remote_sync, to_send_buffer, state.name})
      end)
    else
      Enum.each(state.neighbours, fn neighbour ->
        # Logger.debug("ll #{inspect(name)} propagating to #{inspect(neighbour)}: #{inspect(msg)}")
        BaseLinkLayer.deliver(state, neighbour, {:remote_sync, full_buffer.crdts_deltas})
      end)
    end
    state
  end

end
