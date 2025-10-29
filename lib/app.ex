defmodule CRDTComparison.App do
  alias Analyzer.CrdtAnalyzer
  def start(_type, _args) do
    Application.put_env(:crdt_comparison, :init_wall_clock_time, :os.system_time(:millisecond))


    CrdtAnalyzer.start()


    {:ok, self()}
  end
end
