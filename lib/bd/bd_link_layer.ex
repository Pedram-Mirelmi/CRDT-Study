defmodule BD.BD_LinkLayer do
  require Logger

  def initial_state(_name) do
    %{}
  end

  def handle_propagate(state, msg, bd_sync_method) do
    case bd_sync_method do
      :all ->
        Enum.each(state.neighbours, fn neighbour ->
          BaseLinkLayer.deliver(state, neighbour, msg)
        end)
      :random ->
        neighbour = state.neighbours |> Enum.random()
        BaseLinkLayer.deliver(state, neighbour, msg)
      other ->
        Logger.warning("Unknown sync method #{inspect(other)} in BD_LinkLayer")

    end
    state
  end
end
