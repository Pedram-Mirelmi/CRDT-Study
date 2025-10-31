defmodule BD.BD_Node do
  # alias BD.BD_DB
  alias BD.BD_DB
  alias BD.BD_LinkLayer
  @behaviour BaseNode
  require Logger


  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

  def default_conf() do
    %{
      sync_interval: Application.get_env(:crdt_comparison, :sync_interval, 300),
      bd_push_model1?: Application.get_env(:crdt_comparison, :bd_push_model1?, true),
      bd_push_model2?: Application.get_env(:crdt_comparison, :bd_push_model2?, false),
      bd_pull_model?: Application.get_env(:crdt_comparison, :bd_pull_model?, true),
      bd_sync_method: Application.get_env(:crdt_comparison, :bd_sync_method, :all)
    }
  end

  @impl true
  def initial_state(name, conf) do
    %{
      conf: conf,
      db: BD_DB.new(name),
      name: name
    }
  end

  @impl true
  def ll_module() do
    BD_LinkLayer
  end

  @impl true
  def handle_peer_full_sync(state, _other) do
    # Logger.debug("node #{state.name} syncing...")
    handle_periodic_sync(state)
  end

  @impl true
  def handle_update(state, key, update) do
    # Logger.debug("#{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    new_db = BD_DB.apply_local_update(state.db, key, update)
    if state.conf.bd_push_model2? do
      # Logger.debug("#{inspect(state.name)} pushing vc for key #{inspect(key)}")
      new_vc = new_db |> BD_DB.get_crdt(key) |> elem(1) |> Map.get(:vc)
      BaseLinkLayer.propagate(state.name, {:remote_crdt_vcs, state.name, %{key => new_vc}}, state.conf.bd_sync_method)
    end
    %{state | db: new_db}
  end

  @impl true
  def handle_ll_deliver(state, {:remote_crdt_vcs, remote_replica_name, remote_crdt_vcs}) do
    # Logger.debug("#{inspect(state.name)} received remote_crdt_vcs: #{inspect(remote_crdt_vcs)} from replica #{inspect(remote_replica_name)}")
    two_replicas_delta = BD_DB.compute_delta_from_crdt_vcs(state.db, remote_crdt_vcs)
    # Logger.debug("node #{inspect(state.name)}: deltas: #{inspect(two_replicas_delta)}")
    if Kernel.map_size(two_replicas_delta) > 0 do
      # Logger.debug("#{inspect(state.name)} sending delta #{inspect(two_replicas_delta)} back to replica #{inspect(remote_replica_name)}")
      # Logger.error("sending to replica!")
      BaseLinkLayer.send_to_node(state.name, remote_replica_name, {:remote_deltas, two_replicas_delta})
    else
      # Logger.warning("no delta between the two replicas!!!!")
    end

    if state.conf.bd_push_model1? do
      strictly_older_crdt_vcs = BD_DB.get_strictly_older_crdt_vcs(state.db, remote_crdt_vcs)
      if Kernel.map_size(strictly_older_crdt_vcs) > 0 do
        # Logger.debug("#{inspect(state.name)} pushing strictly older vcs #{inspect(strictly_older_crdt_vcs)} to replica #{inspect(remote_replica_name)}")
        # Logger.error("sending to replica through push!!!")
        BaseLinkLayer.send_to_node(state.name, remote_replica_name, {:remote_crdt_vcs, state.name, strictly_older_crdt_vcs})
      else
        # Logger.error("no strictly older crdt vcs to push!!!!")
      end
    end

    state
  end

  @impl true
  def handle_ll_deliver(state, {:remote_deltas, remote_deltas}) do
    # Logger.warning("#{state.name} getting delta: #{inspect(remote_deltas)}")
    new_db = BD_DB.apply_deltas(state.db, remote_deltas)

    %{state | db: new_db}
  end

  @impl true
  def handle_periodic_sync(state) do
    # if state.conf.bd_pull_model? do
      # Logger.debug("#{inspect(state.name)} pulling")
    BaseLinkLayer.propagate(state.name, {:remote_crdt_vcs, state.name, BD_DB.get_all_vcs(state.db)}, state.conf.bd_sync_method)
    # end

    state
  end

end
