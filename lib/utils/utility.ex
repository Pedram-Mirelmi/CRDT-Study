defmodule Utility do
alias Minidote.Types


  @spec generate_unique_id() :: Types.unique_id()
  def generate_unique_id() do
    {get_node_id(), System.unique_integer([:monotonic])}
  end

  @spec get_node_id() :: Types.md_node_id()
  def get_node_id() do
    {node(), Application.get_env(:minidote, :uuid_seed)}
  end
end
