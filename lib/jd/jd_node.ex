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
    BaseLinkLayer.send_to_replica(state.name, other, {:full_sync_request, state.name})
    state
  end

  @impl true
  def handle_update(state, key, update) do
    # Logger.debug("node #{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    {crdt_type, crdt} = JD_DB.get_crdt(state.db, key)
    delta = CRDT.downstream_effect(crdt_type, crdt, update)
    new_state =
      if state.conf.bp? do
        store(state, %JD_Buffer{crdts_deltas: %{key => %{state.name => MapSet.new([delta])}}})
      else
        store(state, %JD_Buffer{crdts_deltas: %{key => MapSet.new([delta])}})
      end

    new_state
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
  def handle_ll_deliver(state, {:remote_sync, remote_buffer}) do
    strictly_inflating_crdts_deltas = JD_DB.compute_strictly_inflating_deltas(state.db, remote_buffer.crdts_deltas, state.conf.bp?)
    strictly_effective_remote_buffer = %JD_Buffer{crdts_deltas: strictly_inflating_crdts_deltas}
    # Logger.debug("\nnode #{inspect(state.name)} received remote buffer: #{inspect(remote_buffer)}, strictly inflating deltas: #{inspect(strictly_inflating_crdts_deltas)}\nwhile self buffer: #{inspect(state.buffer)}")
    maybe_new_state =
      if strictly_inflating_crdts_deltas != %{} do
        store(state, strictly_effective_remote_buffer)
      else
        state
      end

    maybe_new_state
  end


  @impl true
  def handle_periodic_sync(state) do
    # Logger.debug("node #{inspect(state.name)} syncing with buffer: #{inspect(state.buffer)}")
    if state.buffer.crdts_deltas != %{} do
      BaseLinkLayer.propagate(state.name, {:remote_sync, state.buffer}, state.conf.bp?)
    end

    %{state | buffer: JD_Buffer.new()}
  end

  defp store(state, buffer) do
    # merge state:
    new_db = JD_DB.apply_deltas(state.db, buffer.crdts_deltas, state.conf.bp?)

    # store in self buffer:
    new_buffer = JD_Buffer.merge_buffer(state.buffer, buffer, state.conf.bp?)

    %{state | buffer: new_buffer, db: new_db}
  end

end
