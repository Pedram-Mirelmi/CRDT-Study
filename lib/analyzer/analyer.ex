defmodule Analyzer.CrdtAnalyzer do
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
  def record_network_traffic(replica_name, replica_time_stamp, msg, traffic_type) do
    msg_size = :erlang.external_size(msg)
    GenServer.cast(:analyzer, {:save_traffic, replica_name, replica_time_stamp, msg_size, traffic_type})
  end

  def get_state() do
    GenServer.call(:analyzer, :get_state)
  end

  def reset() do
    GenServer.cast(:analyzer, :reset)
  end

  def record_memory_usage(state) do
    now_wall_clock_time = :erlang.statistics(:wall_clock) |> elem(0)
    replica_time_stamp = now_wall_clock_time - state.init_wall_clock_time
    name = state.name
    db_size = :erlang.external_size(state.db)
    total_state_size = :erlang.external_size(state)
    GenServer.cast(:analyzer, {:save_memory_usage, name, replica_time_stamp, db_size, total_state_size})
  end

  @impl true
  def handle_cast({:save_traffic, replica_name, replica_time_stamp, msg_size, traffic_type}, state) do
    new_state = AnalyzerState.save_traffic(state, replica_name, replica_time_stamp, msg_size, traffic_type)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:save_memory_usage, replica_name, replica_time_stamp, db_size, total_state_size}, state) do
    new_state = AnalyzerState.save_memory_usage(state, replica_name, replica_time_stamp, db_size, total_state_size)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:reset, _state) do
    {:noreply, AnalyzerState.new()}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end



end
