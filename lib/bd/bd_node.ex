defmodule BD.BD_Node do
  # alias BD.DB
  alias BD.DB
  alias BD.BD_LinkLayer
  @behaviour BaseNode
  require Logger


  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

  @impl true
  def initial_state(name, conf) do
    %{
      conf: conf,
      db: DB.new(name),
      name: name
    }
  end

  @impl true
  def ll_module() do
    BD_LinkLayer
  end

  def start_link(name, conf) do
    BaseNode.start_link(name, conf, __MODULE__)
  end

  def start(name, conf) do
    BaseNode.start(name, conf, __MODULE__)
  end

  def connect(name, other) do
    BaseNode.connect(name, other)
  end

  def update(name, key, update) do
    BaseNode.update(name, key, update)
  end

  @impl true
  def get_state(name) do
    BaseNode.get_state(name)
  end

  @impl true
  def handle_update(state, key, update) do
    # Logger.debug("node #{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    new_db = DB.apply_local_update(state.db, key, update)
    %{state | db: new_db}
  end

  @impl true
  def handle_ll_deliver(state, {:remote_crdt_vcs, remote_replica_name, remote_crdt_vcs}) do

    two_replicas_delta = DB.compute_delta_from_crdt_vcs(state.db, remote_crdt_vcs)
    if Kernel.map_size(two_replicas_delta) > 0 do
      # Logger.debug("from node #{inspect(state.name)} sending delta #{inspect(two_replicas_delta)} to replica #{inspect(remote_replica_name)}")
      BD_LinkLayer.send_to_replica(state.name, remote_replica_name, {:remote_deltas, two_replicas_delta}, nil)
      strictly_older_crdt_vcs = DB.get_strictly_older_crdt_vcs(state.db, remote_crdt_vcs)
      if Kernel.map_size(strictly_older_crdt_vcs) > 0 do
        BD_LinkLayer.send_to_replica(state.name, remote_replica_name, {:remote_crdt_vcs, state.name, strictly_older_crdt_vcs}, nil)
      end
    end

    state
  end

  @impl true
  def handle_ll_deliver(state, {:remote_deltas, remote_deltas}) do
    new_db = DB.apply_deltas(state.db, remote_deltas)

    %{state | db: new_db}
  end

  @impl true
  def handle_periodic_sync(state) do
    # Logger.debug("node #{inspect(state.name)} syncing with buffer: #{inspect(state.buffer)}")
    BD_LinkLayer.propagate(state.name, {:remote_crdt_vcs, state.name, DB.get_all_vcs(state.db)}, state.conf.sync_method)

    state
  end

end
