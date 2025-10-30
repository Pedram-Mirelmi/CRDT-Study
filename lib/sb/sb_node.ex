defmodule SB.SB_Node do
  alias SB.DB
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
      db: DB.new(),
      name: name
    }
  end

  @impl true
  def handle_peer_full_sync(state, other) do
    BaseLinkLayer.send_to_replica(state.name, other, {:full_sync_request, state.name})
    state
  end

  @impl true
  def handle_update(state, key, update) do
    new_db = DB.apply_local_update(state.db, key, update)
    %{state | db: new_db}
  end

  @impl true
  def handle_ll_deliver(state, {:full_sync_request, requester_replica}) do
    BaseLinkLayer.send_to_replica(state.name, requester_replica, {:full_sync_response, state.db})
  end

  @impl true
  def handle_ll_deliver(state, {:full_sync_response, remote_db}) do
    %{state | db: remote_db}
  end

  @impl true
  def handle_ll_deliver(state, {:remote_sync, remote_effects}) do
    # Logger.debug("node #{inspect(state.name)} received remote sync: #{inspect(remote_effects)}")
    new_db = DB.apply_remote_effects(state.db, remote_effects)
    %{state | db: new_db}
  end

  @impl true
  def handle_periodic_sync(%{conf: conf, name: name, db: %DB{crdts: crdts, updated_crdts: updated_crdts} = db} = state) do
    # Logger.debug("node #{inspect(name)} syncing")
    if conf.sb_sync_method == :updates_only do
      to_send = Map.take(crdts, Enum.to_list(updated_crdts))
      if to_send != %{} do
        BaseLinkLayer.propagate(name, {:remote_sync, to_send}, nil)
      end
    else
      BaseLinkLayer.propagate(name, {:remote_sync, crdts}, nil)
    end

    new_db = DB.clear_updated_crdts(db)

    %{state | db: new_db}
  end

end
