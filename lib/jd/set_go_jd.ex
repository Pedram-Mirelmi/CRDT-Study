defmodule Crdts.Set_GO_JD do
  alias Crdts.Set_GO_JD
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
    %Set_GO_JD{}
  end

  @impl true
  def value(%Set_GO_JD{adds: adds}) do
    adds
  end

  @impl true
  def downstream_effect(%Set_GO_JD{}, {:add, [element]}) do
    %{adds: MapSet.new([element])}
  end

  def empty_state() do
    %{adds: MapSet.new()}
  end

  @impl true
  def valid_update?(internal_update) do
    case internal_update do
      {:add, [_term]} -> true
      _other -> false
    end
  end

  @impl true
  def valid_effect?(internal_effect) do
    case internal_effect do
      %{adds: %MapSet{}} -> true
      _ -> false
    end
  end

  @impl true
  def affect(%Set_GO_JD{adds: adds}, %{adds: eff_adds}) do
    new_adds = MapSet.union(adds, eff_adds)
    %Set_GO_JD{adds: new_adds}
  end

  # @impl true
  def merge_state(%Set_GO_JD{adds: adds1}, %{adds: adds2}) do
    %Set_GO_JD{adds: MapSet.union(adds1, adds2)}
  end

  @impl true
  def causes_inflation?(%Set_GO_JD{adds: adds}, %{adds: eff_adds}) do
    not MapSet.subset?(eff_adds, adds)
  end


  @impl true
  def equal?(%Set_GO_JD{} = s1, %Set_GO_JD{} = s2) do
    s1.adds == s2.adds
  end
end
