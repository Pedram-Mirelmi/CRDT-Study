defmodule JD.JD_Node do
  alias JD.JD_DB
  alias JD.JD_LinkLayer
  alias Crdts.CRDT
  alias JD.JD_Buffer
  @behaviour BaseNode
  require Logger

  @impl true
  def ll_module() do
    JD_LinkLayer
  end

  def default_conf() do
    %{
      sync_interval: Application.get_env(:crdt_comparison, :sync_interval, 300),
      bp?: Application.get_env(:crdt_comparison, :jd_bp?, true)
    }
  end

  @impl true
  def initial_state(name, conf) do
    %{
      conf: conf,
      buffer: JD_Buffer.new(),
      db: JD_DB.new(),
      name: name
    }
  end

  @impl true
  def handle_peer_full_sync(state, other) do
    # buffer_to_send = if state.conf.bp? do JD_Buffer.remove_jds_from_origin(state.buffer, other) else state.buffer.crdts_deltas end
    BaseLinkLayer.send_to_node(state.name, other, {:full_sync_request, state.name, state.db})
    state
  end

  @impl true
  def handle_update(state, key, update) do
    # Logger.debug("node #{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    {crdt_type, crdt} = JD_DB.get_crdt(state.db, key)
    delta = CRDT.downstream_effect(crdt_type, crdt, update)
    if state.conf.bp? do
      store(state, %{key => MapSet.new([delta])}, state.name)
    else
      store(state, %{key => MapSet.new([delta])})
    end
  end

  @impl true
  def handle_ll_deliver(state, {:full_sync_request, requester_node, remote_db}) do
    # buffer_to_send = if state.conf.bp? do JD_Buffer.remove_jds_from_origin(state.buffer, requester_node) else state.buffer.crdts_deltas end
    BaseLinkLayer.send_to_node(state.name, requester_node, {:full_sync_response, state.db})
    # merge_node_states(state, requester_node, remote_db, remote_buffer)
    %{state | db: JD_DB.merge(state.db, remote_db)}
  end

  @impl true
  def handle_ll_deliver(state, {:full_sync_response, remote_db}) do
    # merge_node_states(state, remote_node, remote_db)
    %{state | db: JD_DB.merge(state.db, remote_db)}
  end

  @impl true
  def handle_ll_deliver(state, {:remote_sync, remote_buffer}) do
    # Logger.debug("#{inspect(state.name)} received remote buffer from #{}: #{inspect(remote_buffer)}, strictly inflating deltas: #{inspect(strictly_inflating_crdts_deltas)}\nwhile self buffer: #{inspect(state.buffer)}")
    store(state, remote_buffer)
  end

  @impl true
  def handle_ll_deliver(state, {:remote_sync, remote_buffer, origin}) do
    # Logger.debug("#{inspect(state.name)} received remote buffer from #{}: #{inspect(remote_buffer)}, strictly inflating deltas: #{inspect(strictly_inflating_crdts_deltas)}\nwhile self buffer: #{inspect(state.buffer)}")
    store(state, remote_buffer, origin)
  end

  @impl true
  def handle_periodic_sync(state) do
    # Logger.debug("node #{inspect(state.name)} syncing with buffer: #{inspect(state.buffer)}")
    if state.buffer.crdts_deltas != %{} do
      BaseLinkLayer.propagate(state.name, {:remote_sync, state.buffer}, state.conf.bp?)
    end

    %{state | buffer: JD_Buffer.new()}
  end

  defp store(state, buffer, origin \\ nil) do
    # merge state:
    {new_db, effective_deltas_in_buffer} = JD_DB.apply_deltas(state.db, buffer)

    # store in self buffer:
    new_buffer = JD_Buffer.store_effective_remote_deltas(state.buffer, effective_deltas_in_buffer, origin)

    %{state | buffer: new_buffer, db: new_db}
  end

  # defp merge_node_states(state, other_node, remote_db, remote_buffer) do
  #   only_buffer_updated_state =
  #     if state.conf.bp? do
  #       store(state, remote_buffer, other_node)
  #     else
  #       store(state, remote_buffer)
  #     end
  #   new_db = JD_DB.merge(state.db, remote_db)
  #   %{state | db: new_db, buffer: only_buffer_updated_state.buffer}
  # end

end
