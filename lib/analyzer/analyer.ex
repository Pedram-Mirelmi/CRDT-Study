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


  def record_outgoing_traffic(node_name, msg) do
    GenServer.cast(:analyzer, {:save_outgoing_traffic, node_name, msg})
  end

  def record_incomming_traffic(node_name, msg) do
    # if node_name == "node1" do
    #   Logger.debug("node1 received: #{inspect(msg)}")
    # end
    GenServer.cast(:analyzer, {:save_incomming_traffic, node_name, msg})
  end

  def get_state() do
    GenServer.call(:analyzer, :get_state)
  end

  @impl true
  def handle_cast({:save_outgoing_traffic, node_name, msg}, state) do
    new_state = AnalyzerState.save_outgoing(state, node_name, msg)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:save_incomming_traffic, node_name, msg}, state) do
    new_state = AnalyzerState.save_incomming(state, node_name, msg)
    {:noreply, new_state}
  end


  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end



end
