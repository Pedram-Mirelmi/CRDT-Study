defmodule Analyzer.AnalyzerState do
  alias Analyzer.AnalyzerState
  defstruct init_time: nil,
    outgoing_traffic: %{}, # node => [{time_stamp, msg_size_in_bytes}]
    incoming_traffic: %{}


  def new() do
    %AnalyzerState{init_time: :os.system_time(:millisecond)}
  end

  def save_incomming(%AnalyzerState{} = this, node_name, msg) do
    msg_size = msg |> :erlang.term_to_binary() |> byte_size()
    entry = {:os.system_time(:millisecond) - this.init_time, msg_size}
    updated_map = Map.update(this.incoming_traffic, node_name, [entry], &([entry | &1]))
    %{this | incoming_traffic: updated_map}
  end

  def save_outgoing(%AnalyzerState{} = this, node_name, msg) do
    msg_size = msg |> :erlang.term_to_binary() |> byte_size()
    entry = {:os.system_time(:millisecond) - this.init_time, msg_size}
    updated_map = Map.update(this.outgoing_traffic, node_name, [entry], &([entry | &1]))
    %{this | outgoing_traffic: updated_map}
  end
end
