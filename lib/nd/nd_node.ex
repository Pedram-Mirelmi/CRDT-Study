defmodule ND.ND_Node do
  alias ND.ND_Buffer
  alias ND.ND_DB
  alias LinkLayer.ND_LinkLayer
  alias Crdts.CRDT
  @behaviour BaseNode
  require Logger

  def atom_name(node_name) do
    node_name |> String.to_atom()
  end

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

  defp store(state, remote_buffer) do
    {new_db, effective_deltas_in_buffer} = ND_DB.apply_deltas(state.db, remote_buffer, state.conf.bp?)
    new_buffer = ND_Buffer.store_effective_remote_deltas(state.buffer, effective_deltas_in_buffer, state.conf.bp?)

    %{state | db: new_db, buffer: new_buffer}
  end


  @impl true
  def handle_update(state, key, update) do
    Logger.debug("node #{inspect(state.name)} updating #{inspect(key)} with #{inspect(update)}")
    {crdt_type, crdt} = ND_DB.get_crdt(state.db, key)
    delta = CRDT.downstream_effect(crdt_type, crdt, update)
    if state.conf.bp? do
      store(state, %ND_Buffer{crdts_deltas: %{key => %{state.name => delta}}})
    else
      store(state, %ND_Buffer{crdts_deltas: %{key => delta}})
    end
  end

  @impl true
  def handle_ll_deliver(state, {:remote_sync, remote_effects}) do
    store(state, remote_effects)
  end

  @impl true
  def handle_periodic_sync(state) do
    # Logger.debug("node #{inspect(state.name)} syncing")
    ND_LinkLayer.propagate(state.name, {:remote_sync, state.buffer}, bp?: state.conf.bp?)
    %{state | buffer: %ND_Buffer{}}
  end

end
