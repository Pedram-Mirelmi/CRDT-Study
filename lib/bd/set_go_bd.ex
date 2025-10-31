defmodule Crdts.Set_GO_BD do
  require Logger
  alias Utility.VectorClock
  alias Crdts.Set_GO_BD
  @behaviour Crdts.CRDT



  defstruct elements: %{}, vc: VectorClock.new()

  @type set_element :: term()
  @type operation :: :add
  @type args :: [set_element()]
  @type internal_update :: {operation(), args()}

  @type internal_effect :: %{elements: map()}

  @type value() :: MapSet.t(set_element())

  @impl true
  def new() do
    %Set_GO_BD{}
  end

  @impl true
  def value(%Set_GO_BD{elements: elements}) do
    Map.keys(elements) |> MapSet.new()
  end

  @impl true
  def downstream_effect(%Set_GO_BD{elements: elements, vc: vc}, {:add, [element]}) do
    replica = Process.info(self(), :registered_name) |> elem(1)
    if not Map.has_key?(elements, element) do
      new_vc = VectorClock.increment(vc, replica)
      count = VectorClock.get(new_vc, replica)
      %{elements: %{element => %VectorClock{v: %{replica => count}}}}
    else
      %{elements: %{}}
    end
  end

  def get_delta(%Set_GO_BD{elements: elements}, since_vc) do
    delta_elements =
      Map.filter(elements, fn {_el, el_vc} ->
        not VectorClock.leq(el_vc, since_vc)
      end)
    %{elements: delta_elements}
  end

  def empty_state() do
    %{elements: Map.new(), vc: VectorClock.new()}
  end

  @impl true
  def affect(%Set_GO_BD{elements: elements, vc: vc}, %{elements: eff_elements}) do
    new_elements = Map.merge(elements, eff_elements, fn _el, vc1, vc2 ->
      VectorClock.merge(vc1, vc2)
    end)
    new_vc = Enum.reduce(eff_elements, vc, fn {_el, eff_vc}, acc_vc ->
      VectorClock.merge(acc_vc, eff_vc)
    end)

    %Set_GO_BD{elements: new_elements, vc: new_vc}
  end

  @impl true
  def causes_inflation?(%Set_GO_BD{elements: elements}, %{elements: eff_adds}) do
    Enum.any?(eff_adds, fn {el, eff_vc} ->
      case Map.get(elements, el) do
        nil -> true
        local_vc -> VectorClock.gt(eff_adds, local_vc)
      end
    end)
  end


  @impl true
  def equal?(%Set_GO_BD{} = s1, %Set_GO_BD{} = s2) do
    s1.elements == s2.elements
  end
end
