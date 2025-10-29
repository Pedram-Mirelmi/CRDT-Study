defmodule BaseNode do
  alias Analyzer.CrdtAnalyzer
  use GenServer
  require Logger

  @callback initial_state(binary(), map()) :: map()
  @callback ll_module() :: module()
  @callback handle_update(map(), tuple(), tuple()) :: map()
  @callback handle_ll_deliver(map(), tuple()) :: map()
  @callback handle_periodic_sync(map()) :: map()
  @callback get_state(binary()) :: map()

  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

  defp base_initial_state(name, conf) do
    %{
      name: name,
      conf: conf,
      init_wall_clock_time: :erlang.statistics(:wall_clock) |> elem(0)
    }
  end

  def initial_state(name, conf, module) do
    base_state = base_initial_state(name, conf)
    module_state = module.initial_state(name, conf)
    base_state |> Map.merge(module_state) |> Map.put(:module, module)
  end

  def start_link(name, conf, module) do
    GenServer.start_link(
      __MODULE__,
      initial_state(name, conf, module),
      name: atom_name(name)
    )
  end

  def start(name, conf, module) do
    GenServer.start(
      __MODULE__,
      initial_state(name, conf, module),
      name: atom_name(name)
    )
  end

  def stop(name) do
    GenServer.stop(atom_name(name))
    BaseLinkLayer.stop(name)
  end

  @impl true
  def init(%{name: name, module: module} = init_state) do
    ll_module = module.ll_module()

    {:ok, _pid} = ll_module.start_link(name)

    ll_module.subscribe(name, {:gen, atom_name(name)}, :ll_deliver)

    Process.send_after(self(), :periodic_sync, init_state.conf.sync_interval)

    record_memory_usage(init_state)

    {:ok, init_state}
  end



  def connect(name, other) do
    :ok = GenServer.call(atom_name(name), {:connect, other})
  end

  def update(name, key, update) do
    :ok = GenServer.cast(atom_name(name), {:update, key, update})
  end

  def get_state(name) do
    GenServer.call(atom_name(name), :get_state)
  end

  def record_memory_usage(state) do
    now_wall_clock_time = :erlang.statistics(:wall_clock) |> elem(0)
    replica_time_stamp = now_wall_clock_time - state.init_wall_clock_time
    CrdtAnalyzer.record_memory_usage(state, replica_time_stamp)
  end

  @spec sync_now(binary()) :: any()
  def sync_now(name) do
    send(atom_name(name), :periodic_sync)
  end

  @impl true
  def handle_call({:connect, other}, _from, %{name: name} = state) do
    :ok = state.module.ll_module().connect(name, other)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update, key, update}, state) do
    new_state = state.module.handle_update(state, key, update)
    record_memory_usage(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:ll_deliver, msg}, state) do
    new_state = state.module.handle_ll_deliver(state, msg)
    record_memory_usage(new_state)
    {:noreply, new_state}
  end


  @impl true
  def handle_info(:periodic_sync, state) do
    new_state = state.module.handle_periodic_sync(state)
    record_memory_usage(new_state)
    Process.send_after(self(), :periodic_sync, state.conf.sync_interval)
    {:noreply, new_state}
  end
end
