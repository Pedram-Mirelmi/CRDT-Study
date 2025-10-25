defmodule BD.BD_Node do
  # alias BD.DB
  alias BD.DB
  alias BD.BD_LinkLayer
  use GenServer
  require Logger


  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

  defp initial_state(name, conf) do
    %{
      conf: conf,
      db: DB.new(name),
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
    {:ok, _pid} = BD_LinkLayer.start_link(name)
    BD_LinkLayer.subscribe(name, {:gen, atom_name(name)}, :ll_deliver)

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


  @impl true
  def handle_call({:connect, other}, _from, %{name: name} = state) do
    :ok = BD_LinkLayer.connect(name, other)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end


  @impl true
  def handle_cast({:update, key, update}, state) do
    Logger.debug("node #{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    new_db = DB.apply_local_update(state.db, key, update)
    {:noreply, %{state | db: new_db}}
  end

  @impl true
  def handle_cast({:ll_deliver, {:remote_crdt_vcs, remote_replica_name, remote_crdt_vcs}}, state) do

    two_replicas_delta = DB.compute_delta_from_crdt_vcs(state.db, remote_crdt_vcs)
    if Kernel.map_size(two_replicas_delta) > 0 do
      Logger.debug("from node #{inspect(state.name)} sending delta #{inspect(two_replicas_delta)} to replica #{inspect(remote_replica_name)}")
      BD_LinkLayer.send_to_replica(state.name, remote_replica_name, {:remote_deltas, two_replicas_delta}, nil)
      strictly_older_crdt_vcs = DB.get_strictly_older_crdt_vcs(state.db, remote_crdt_vcs)
      if Kernel.map_size(strictly_older_crdt_vcs) > 0 do
        BD_LinkLayer.send_to_replica(state.name, remote_replica_name, {:remote_crdt_vcs, state.name, strictly_older_crdt_vcs}, nil)
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:ll_deliver, {:remote_deltas, remote_deltas}}, state) do
    new_db = DB.apply_deltas(state.db, remote_deltas)

    {:noreply, %{state | db: new_db}}
  end

  @impl true
  def handle_cast(msg, state) do
    Logger.warning("Unhandled cast msg to #{inspect(state.name)}: #{inspect(msg)}")
    {:noreply, state}
  end


  @impl true
  def handle_info({:periodic_sync}, state) do
    # Logger.debug("node #{inspect(state.name)} syncing with buffer: #{inspect(state.buffer)}")
    BD_LinkLayer.propagate(state.name, {:remote_crdt_vcs, state.name, DB.get_all_vcs(state.db)}, state.conf.sync_method)

    Process.send_after(self(), {:periodic_sync}, state.conf.sync_interval)
    {:noreply, state}
  end


  @impl true
  def handle_info(msg, %{name: name} = state) do
    Logger.warning("Unhandled info msg to #{inspect(name)}: #{inspect(msg)}")
    {:noreply, state}
  end

end
