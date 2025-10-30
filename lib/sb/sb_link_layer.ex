defmodule LinkLayer.SB_LinkLayer do
  require Logger

  def initial_state(_name) do
    %{}
  end

  def handle_propagate(state, msg, _conf) do
    Enum.each(state.neighbours, fn neighbour ->
      # Logger.debug("ll #{inspect(name)} propagating to #{inspect(neighbour)}: #{inspect(msg)}")
      BaseLinkLayer.deliver(state, neighbour, msg)
    end)
    state
  end

end
