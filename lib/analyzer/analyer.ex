defmodule CrdtAnalyzer do
  require Logger
  alias Analyzer.AnalyzerState
  use GenServer

  def start_link() do
    GenServer.start_link(
      __MODULE__,
      AnalyzerState.new(),
      name: :analyzer
    )
  end

  def start() do
    GenServer.start(
      __MODULE__,
      AnalyzerState.new(),
      name: :analyzer
    )
  end

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end


  def record_outgoing_traffic(node_name, traffic_size, process_wall_clock_time) do
    GenServer.cast(:analyzer, {:save_outgoing_traffic, node_name, traffic_size, process_wall_clock_time})
  end


  def record_incomming_traffic(node_name, traffic_size, process_wall_clock_time) do
    GenServer.cast(:analyzer, {:save_incomming_traffic, node_name, traffic_size, process_wall_clock_time})
  end

  def record_network_traffic(replica_name, replica_time_stamp, msg, traffic_type) do
    msg_size = :erlang.external_size(msg)
    GenServer.cast(:analyzer, {:save_traffic, replica_name, replica_time_stamp, msg_size, traffic_type})
  end

  def get_state() do
    GenServer.call(:analyzer, :get_state)
  end


  @impl true
  def handle_cast({:save_traffic, replica_name, replica_time_stamp, msg_size, traffic_type}, state) do
    new_state = AnalyzerState.save_traffic(state, replica_name, replica_time_stamp, msg_size, traffic_type)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end



end
