defmodule BD.BD_LinkLayer do
  require Logger

  def initial_state(_name) do
    %{}
  end

  def handle_propagate(state, msg, bd_sync_method) do
    # Logger.debug(" #{state.name} syncing")
    case bd_sync_method do
      :all ->
        Enum.each(state.neighbours, fn neighbour ->
          # Logger.debug("#{state.name} pulling from #{neighbour} to periodic sync")
          BaseLinkLayer.deliver(state, neighbour, msg)
        end)
      :random ->
        neighbours = state.neighbours
        if MapSet.size(neighbours) != 0 do
          neighbour = state.neighbours |> Enum.random()
          # Logger.debug("#{state.name} pulling from #{neighbour} to periodic sync")
          BaseLinkLayer.deliver(state, neighbour, msg)
        end
      other ->
        Logger.warning("Unknown sync method #{inspect(other)} in BD_LinkLayer")
    end
    state
  end
end
