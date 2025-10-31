defmodule ND.ND_Node do
  alias ND.ND_Buffer
  alias ND.ND_DB
  alias LinkLayer.ND_LinkLayer
  alias Crdts.CRDT
  @behaviour BaseNode
  require Logger


  @impl true
  def ll_module() do
    ND_LinkLayer
  end

  def default_conf() do
    %{
      sync_interval: Application.get_env(:crdt_comparison, :sync_interval, 300),
      bp?: Application.get_env(:crdt_comparison, :bp?, true)
    }
  end

  @impl true
  def initial_state(name, conf) do
    %{
      conf: conf,
      db: ND_DB.new(),
      buffer: ND_Buffer.new(),
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
    # Logger.debug("node #{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    {crdt_type, crdt} = ND_DB.get_crdt(state.db, key)
    delta = CRDT.downstream_effect(crdt_type, crdt, update)
    if state.conf.bp? do
      store(state, %{key => delta}, state.name)
    else
      store(state, %{key => delta})
    end
  end

  @impl true
  def handle_ll_deliver(state, {:full_sync_request, requester_node, remote_db}) do
    # buffer_to_send = if state.conf.bp? do JD_Buffer.remove_jds_from_origin(state.buffer, requester_node) else state.buffer.crdts_deltas end
    BaseLinkLayer.send_to_node(state.name, requester_node, {:full_sync_response, state.db})
    # merge_node_states(state, requester_node, remote_db, remote_buffer)
    %{state | db: ND_DB.merge(state.db, remote_db)}
  end

  @impl true
  def handle_ll_deliver(state, {:full_sync_response, remote_db}) do
    # merge_node_states(state, remote_node, remote_db)
    %{state | db: ND_DB.merge(state.db, remote_db)}
  end

  @impl true
  def handle_ll_deliver(state, {:remote_sync, remote_effects, origin}) do
    store(state, remote_effects, origin)
  end

  @impl true
  def handle_ll_deliver(state, {:remote_sync, remote_effects}) do
    store(state, remote_effects)
  end

  @impl true
  def handle_periodic_sync(state) do
    # Logger.debug("node #{inspect(state.name)} syncing")
    if state.buffer.crdts_deltas != %{} do
      BaseLinkLayer.propagate(state.name, {:remote_sync, state.buffer}, state.conf.bp?)
    end
    %{state | buffer: ND_Buffer.new()}
  end


  defp store(state, buffer, origin \\ nil) do # nil means not bp-optimized
    {new_db, effective_deltas_in_buffer} = ND_DB.apply_deltas(state.db, buffer)

    new_buffer = ND_Buffer.store_effective_remote_deltas(state.buffer, effective_deltas_in_buffer, origin)

    %{state | db: new_db, buffer: new_buffer}
  end

  # defp merge_node_states(state, other_node, remote_db, remote_buffer) do
  #   new_buffer =
  #     if state.conf.bp? do
  #       store(state, remote_buffer, other_node)
  #     else
  #       store(state, remote_buffer)
  #     end
  #   new_db = ND_DB.merge(state.db, remote_db)
  #   %{state | db: new_db, buffer: new_buffer}
  # end

end
