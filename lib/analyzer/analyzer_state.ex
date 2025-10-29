defmodule Analyzer.AnalyzerState do
  require Logger
  alias Analyzer.AnalyzerState
  defstruct outgoing_traffic: %{}, # node => [{time_stamp, msg_size_in_bytes}]
    incoming_traffic: %{}, # same
    db_sizes: %{}, # node => [{time_stamp, db_size_in_bytes}]
    total_state_sizes: %{} # node => [{time_stamp, total_state_size_in_bytes


  def new() do
    %AnalyzerState{}
  end

  def save_traffic(this, replica_name, replica_time_stamp, msg_size, traffic_type) do
    entry = {replica_time_stamp, msg_size}
    case traffic_type do
      :in ->
        %{this | incoming_traffic: Map.update(this.incoming_traffic, replica_name, [entry, {0,0}], &([entry | &1]))}
      :out ->
        %{this | outgoing_traffic: Map.update(this.outgoing_traffic, replica_name, [entry, {0,0}], &([entry | &1]))}
      other ->
        Logger.warning("unknown traffic type: #{inspect(traffic_type)}: #{inspect(other)}")
        this
    end
  end

  def save_memory_usage(this, replica_name, replica_time_stamp, db_size, total_state_size) do
    db_entry = {replica_time_stamp, db_size}
    total_state_size_entry = {replica_time_stamp, total_state_size}
    %{this |
      db_sizes: Map.update(this.db_sizes, replica_name, [db_entry], &([db_entry | &1])),
      total_state_sizes: Map.update(this.total_state_sizes, replica_name, [total_state_size_entry], &([total_state_size_entry | &1]))
    }
  end
end
