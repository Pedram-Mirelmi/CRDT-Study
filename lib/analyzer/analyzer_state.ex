defmodule Analyzer.AnalyzerState do
  require Logger
  alias Analyzer.AnalyzerState
  defstruct outgoing_traffic: %{}, # node => [{time_stamp, msg_size_in_bytes}]
    incoming_traffic: %{} # same


  def new() do
    %AnalyzerState{}
  end

  def save_traffic(this, replica_name, replica_time_stamp, msg_size, traffic_type) do
    entry = {replica_time_stamp, msg_size}
    case traffic_type do
      :in ->
        %{this | incoming_traffic: Map.update(this.incoming_traffic, replica_name, [entry], &([entry | &1]))}
      :out ->
        %{this | outgoing_traffic: Map.update(this.outgoing_traffic, replica_name, [entry], &([entry | &1]))}
      other ->
        Logger.warning("unknown traffic type: #{inspect(traffic_type)}: #{inspect(other)}")
        this
    end
  end
end
