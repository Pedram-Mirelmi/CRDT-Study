defmodule BD.BD_LinkLayer do
  require Logger

  def initial_state(_name) do
    %{}
  end
  
  def handle_propagate(state, msg, bd_sync_method) do
    case bd_sync_method do
      :all ->
        Enum.each(state.neighbours, fn neighbour ->
          BaseLinkLayer.record_network_traffic(state, msg, :out)
          BaseLinkLayer.deliver(neighbour, msg)
        end)
      :random ->
        neighbour = state.neighbours |> Enum.random()
        BaseLinkLayer.record_network_traffic(state, msg, :out)
        BaseLinkLayer.deliver(neighbour, msg)
      other ->
        Logger.warning("Unknown sync method #{inspect(other)} in BD_LinkLayer")

    end
    state
  end
end
