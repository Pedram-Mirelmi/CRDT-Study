defmodule Utility.SubHandler do
  defstruct topics_subs: %{}

  @moduledoc """
  The `Utility.SubHandler` module implements a lightweight internal **pub/sub system**
  used to manage subscriptions and message delivery between components in Minidote.

  It is used across the Link Layer and Broadcast Stack to deliver messages like:
  - Broadcasts (`:ll_deliver`, `:beb_deliver`, `:rb_deliver`, `:rcob_deliver`)
  - Cluster membership events (`:cluster_topology_topic`)

  ### Responsibilities:
  - Tracks **subscriptions by topic**, associating each topic with a set of subscribers.
  - Supports two types of subscribers:
    - `{:gen, pid}` — sends messages to a GenServer via `GenServer.cast/2`
    - `{:fn, function}` — invokes a function with the message payload
  - Handles **topic-based broadcasting** using `publish/3`.

  ### Usage:
  - Create a new handler via `SubHandler.new/0`
  - Add topics using `add_topic/2`
  - Add subscriptions using `add_subscription/3`
  - Deliver messages using `publish/3`

  The `SubHandler` is included in the state of `LLGateway` and all broadcast layers,
  allowing them to forward messages cleanly across layers via topic-based pub/sub.

  ### Example:
  ```elixir
  sub_handler
  |> SubHandler.add_topic(:ll_deliver)
  |> SubHandler.add_subscription({:gen, some_pid}, :ll_deliver)
  |> SubHandler.add_subscription({:fn, &some_function/1}, :ll_deliver)
  |> SubHandler.publish(:ll_deliver, {:from, msg})
  ```
  """

  @type topic() :: atom()
  @type subscription() :: {:fn, fun() | function()} | {:gen, pid() | atom()}
  @type t() :: %__MODULE__{topics_subs: %{topic() => MapSet.t(subscription())}}

  require Logger
  alias Utility.SubHandler
  @spec new() :: t()
  def new() do
    %SubHandler{}
  end

  @spec add_topic(t(), topic()) :: t()
  def add_topic(%SubHandler{topics_subs: top_subs} = handler, new_topic) do
    %SubHandler{handler | topics_subs: Map.put(top_subs, new_topic, MapSet.new()) }
  end

  @spec contains_topic?(t(), topic()) :: boolean()
  def contains_topic?(%SubHandler{topics_subs: top_subs}, topic) do
    Map.has_key?(top_subs, topic)
  end

  @spec add_subscription(t(), subscription(), topic()) :: t()
  def add_subscription(%SubHandler{topics_subs: top_subs} = handler, new_subscription, topic) do
    new_top_subs =
      if contains_topic?(handler, topic) do
        subs = Map.get(top_subs, topic)
        new_subs = MapSet.put(subs, new_subscription)
        Map.put(top_subs, topic, new_subs)
      else
        Map.put(top_subs, topic, MapSet.new([new_subscription]))
      end
    %SubHandler{handler | topics_subs: new_top_subs}
  end

  @spec publish(t(), topic(), term()) :: :ok
  def publish(%SubHandler{topics_subs: top_subs} = handler, topic, msg) do
    if contains_topic?(handler, topic) do
      subs = Map.get(top_subs, topic)
      Enum.each(subs, fn sub ->
        case sub do
          {:gen, pid} ->
            GenServer.cast(pid, {topic, msg})
          {:fn, f} ->
            f.(msg)
        end
      end)
      :ok
    else
      Logger.warning("Topic #{inspect(topic)} not exists to publish, node: #{inspect(node())}")
      {:error, :topic_not_found}
    end
    :ok
  end

end
