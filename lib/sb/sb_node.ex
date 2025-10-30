defmodule SB.SB_Node do
  alias SB.SB_DB
  alias LinkLayer.SB_LinkLayer
  @behaviour BaseNode
  require Logger

  @impl true
  def ll_module() do
    SB_LinkLayer
  end

  def default_conf() do
    %{
      sync_interval: Application.get_env(:crdt_comparison, :sync_interval, 300),
      sb_sync_method: Application.get_env(:crdt_comparison, :sb_sync_method, :updates_only)
    }
  end

  @impl true
  def initial_state(name, conf) do
    %{
      conf: conf,
      db: SB_DB.new(),
      name: name
    }
  end

  @impl true
  def handle_peer_full_sync(state, other) do
    BaseLinkLayer.send_to_node(state.name, other, {:full_sync_request, state.name, state.db})
    state
  end

  @impl true
  def handle_update(state, key, update) do
    new_db = SB_DB.apply_local_update(state.db, key, update)
    %{state | db: new_db}
  end

  @impl true
  def handle_ll_deliver(state, {:full_sync_request, requester_replica, remote_db}) do
    BaseLinkLayer.send_to_node(state.name, requester_replica, {:full_sync_response, state.db})
    %{state | db: SB_DB.merge(state.db, remote_db)}
  end

  @impl true
  def handle_ll_deliver(state, {:full_sync_response, remote_db}) do
    %{state | db: SB_DB.merge(state.db, remote_db)}
  end

  @impl true
  def handle_ll_deliver(state, {:remote_sync, remote_effects}) do
    # Logger.debug("node #{inspect(state.name)} received remote sync: #{inspect(remote_effects)}")
    new_db = SB_DB.apply_remote_effects(state.db, remote_effects)
    %{state | db: new_db}
  end

  @impl true
  def handle_periodic_sync(%{conf: conf, name: name, db: %SB_DB{crdts: crdts, updated_crdts: updated_crdts} = db} = state) do
    # Logger.debug("node #{inspect(name)} syncing")
    if conf.sb_sync_method == :updates_only do
      to_send = Map.take(crdts, Enum.to_list(updated_crdts))
      if to_send != %{} do
        BaseLinkLayer.propagate(name, {:remote_sync, to_send}, nil)
      end
    else
      BaseLinkLayer.propagate(name, {:remote_sync, crdts}, nil)
    end

    new_db = SB_DB.clear_updated_crdts(db)

    %{state | db: new_db}
  end

end
