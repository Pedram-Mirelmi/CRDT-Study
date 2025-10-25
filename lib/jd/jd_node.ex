defmodule JD.JD_Node do
  alias JD.DB
  alias JD.JD_LinkLayer
  alias Crdts.CRDT
  alias JD.Buffer
  use GenServer
  require Logger

  @moduledoc """
    buffer: %{
      {key_bin, crdt_type} => join_decompositions
    }

    join_decompositions:
      if bp?:
        %{
          origin1 => %MapSet{jd1, jd2, ...},
          origin2 => %MapSet{jd3, jd4, ...}
        }
      else:
        %MapSet{jd1, jd2, ...}

  """

  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

  defp initial_state(name, conf) do
    %{
      conf: conf,
      buffer: Buffer.new(),
      db: DB.new(),
      name: name
    }
  end

  def start_link(name, conf) do
    GenServer.start_link(
      __MODULE__,
      initial_state(name, conf),
      name: atom_name(name)
    )
  end

  def start(name, conf) do
    GenServer.start(
      __MODULE__,
      initial_state(name, conf),
      name: atom_name(name)
    )
  end

  def stop(name) do
    GenServer.stop(atom_name(name))
  end

  @impl true
  def init(%{name: name} = init_state) do
    # Logger.debug("node #{inspect(name)} inited!")
    {:ok, _pid} = JD_LinkLayer.start(name)
    JD_LinkLayer.subscribe(name, {:gen, atom_name(name)}, :ll_deliver)

    Process.send_after(self(), {:periodic_sync}, init_state.conf.sync_interval)

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

  defp store(state, buffer) do
    new_state = merge_state(state, buffer)
    new_buffer = Buffer.merge_buffer(new_state.buffer, buffer, state.conf.bp?)

    %{new_state | buffer: new_buffer}
  end

  @impl true
  def handle_call({:connect, other}, _from, %{name: name} = state) do
    :ok = JD_LinkLayer.connect(name, other)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end


  @impl true
  def handle_cast({:update, key, update}, state) do
    Logger.debug("node #{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    {crdt_type, crdt} = DB.get_crdt(state.db, key)
    delta = CRDT.downstream_effect(crdt_type, crdt, update)
    new_state =
      if state.conf.bp? do
        store(state, %Buffer{bp_optimized_data: %{key => %{state.name => MapSet.new([delta])}}})
      else
        store(state, %Buffer{regular_data: %{key => MapSet.new([delta])}})
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:ll_deliver, {:remote_sync, remote_buffer}}, state) do
    # Logger.debug("node #{inspect(state.name)} received remote sync: #{inspect(remote_crdts_delta_groups)}")

    strictly_inflating_crdts_deltas = DB.compute_delta(state.db, remote_buffer, state.conf.bp?)

    maybe_new_crdts =
      if strictly_inflating_crdts_deltas != %{} do
        store(state, remote_buffer)
      else
        state
      end

    {:noreply, maybe_new_crdts}
  end


  @impl true
  def handle_info({:periodic_sync}, state) do
    # Logger.debug("node #{inspect(state.name)} syncing with buffer: #{inspect(state.buffer)}")
    JD_LinkLayer.propagate(state.name, {:remote_sync, state.buffer}, state.conf.bp?)

    Process.send_after(self(), {:periodic_sync}, state.conf.sync_interval)
    {:noreply, %{state | buffer: Buffer.new()}}
  end


  @impl true
  def handle_info(msg, %{name: name} = state) do
    Logger.warning("Unhandled info msg to #{inspect(name)}: #{inspect(msg)}")
    {:noreply, state}
  end


  defp merge_state(state, delta_buffer) do
    new_db =
      if state.conf.bp? do
        DB.apply_deltas(state.db, delta_buffer.bp_optimized_data, state.conf.bp?)
      else
        DB.apply_deltas(state.db, delta_buffer.regular_data, state.conf.bp?)
      end
    %{state | db: new_db}
  end


end
