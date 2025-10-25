defmodule JD.JD_Node do
  alias JD.DB
  alias JD.JD_LinkLayer
  alias Crdts.CRDT
  alias JD.Buffer
  @behaviour BaseNode
  require Logger

  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

  @impl true
  def ll_module() do
    JD_LinkLayer
  end

  @impl true
  def initial_state(name, conf) do
    %{
      conf: conf,
      buffer: Buffer.new(),
      db: DB.new(),
      name: name
    }
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

  defp store(state, buffer) do
    new_state = merge_state(state, buffer)
    new_buffer = Buffer.merge_buffer(new_state.buffer, buffer, state.conf.bp?)

    %{new_state | buffer: new_buffer}
  end

  @impl true
  def handle_update(state, key, update) do
    Logger.debug("node #{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    {crdt_type, crdt} = DB.get_crdt(state.db, key)
    delta = CRDT.downstream_effect(crdt_type, crdt, update)
    new_state =
      if state.conf.bp? do
        store(state, %Buffer{bp_optimized_data: %{key => %{state.name => MapSet.new([delta])}}})
      else
        store(state, %Buffer{regular_data: %{key => MapSet.new([delta])}})
      end

    new_state
  end

  @impl true
  def handle_ll_deliver(state, {:remote_sync, remote_buffer}) do
    strictly_inflating_crdts_deltas = DB.compute_delta(state.db, remote_buffer, state.conf.bp?)

    maybe_new_state =
      if strictly_inflating_crdts_deltas != %{} do
        store(state, remote_buffer)
      else
        state
      end

    maybe_new_state
  end


  @impl true
  def handle_periodic_sync(state) do
    # Logger.debug("node #{inspect(state.name)} syncing with buffer: #{inspect(state.buffer)}")
    JD_LinkLayer.propagate(state.name, {:remote_sync, state.buffer}, state.conf.bp?)

    %{state | buffer: Buffer.new()}
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
