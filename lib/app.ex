defmodule CRDTComparison.App do
  def start(_type, _args) do

    CrdtAnalyzer.start()
    # {tree, n_nodes} = StateBased.start(3, %{topology: :tree})
    # BinTree.traverse()

    {:ok, self()}
  end
end
