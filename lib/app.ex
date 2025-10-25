defmodule CRDTComparison.App do
  def start(_type, _args) do
    Application.put_env(:crdt_comparison, :init_wall_clock_time, :os.system_time(:millisecond))
    


    CrdtAnalyzer.start()
    # {tree, n_nodes} = StateBased.start(3, %{topology: :tree})
    # BinTree.traverse()

    {:ok, self()}
  end
end
