defmodule Crdts.Set_GO_SB do
  alias Crdts.Set_GO_SB
  defstruct adds: MapSet.new()
  @behaviour Crdts.CRDT

  @type set_element :: term()
  @type operation :: :add
  @type args :: [set_element()]
  @type internal_update :: {operation(), args()}

  @type internal_effect :: %{adds: MapSet.t()}

  @type value() :: MapSet.t(set_element())

  @impl true
  def new() do
    %Set_GO_SB{}
  end

  @impl true
  def value(%Set_GO_SB{adds: adds}) do
    adds
  end

  @impl true
  def downstream_effect(%Set_GO_SB{adds: adds}, {:add, [element]}) do
    new_adds = MapSet.put(adds, element)
    %{adds: new_adds}
  end

  @impl true
  def affect(%Set_GO_SB{adds: adds}, %{adds: eff_adds}) do
    new_adds = MapSet.union(adds, eff_adds)
    %Set_GO_SB{adds: new_adds}
  end

  @impl true
  def causes_inflation?(%Set_GO_SB{adds: adds}, %{adds: eff_adds}) do
    not MapSet.subset?(eff_adds, adds)
  end


  @impl true
  def equal?(%Set_GO_SB{} = s1, %Set_GO_SB{} = s2) do
    s1.adds == s2.adds
  end

end
