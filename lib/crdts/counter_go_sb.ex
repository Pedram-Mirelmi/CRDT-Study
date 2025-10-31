defmodule Crdts.Counter_GO do
  alias Utility.VectorClock
  alias Crdts.Counter_GO
  @behaviour Crdts.CRDT

  @type replica() :: binary()
  @type operation :: :increment
  @type args :: [replica()]
  @type internal_update :: {operation(), args()}


  # GCounter can be represented as a vc!
  defstruct vc: VectorClock.new()

  @impl true
  def new() do
    %Counter_GO{}
  end

  @impl true
  def value(%Counter_GO{vc: vc}) do
    vc.v |> Map.values() |> Enum.sum()
  end

  @impl true
  def downstream_effect(%Counter_GO{vc: vc}, {:increment, []}) do
    replica = Process.info(self(), :registered_name) |> elem(1)
    new_vc = VectorClock.increment(vc, replica)
    %Counter_GO{vc: new_vc}
  end

  @impl true
  def affect(%Counter_GO{vc: vc}, %Counter_GO{vc: eff_vc}) do
    new_vc = VectorClock.merge(vc, eff_vc)
    %Counter_GO{vc: new_vc}
  end

  @impl true
  def causes_inflation?(%Counter_GO{vc: vc}, %Counter_GO{vc: eff_vc}) do
    not VectorClock.leq(eff_vc, vc)
  end

  def get_delta(%Counter_GO{vc: vc}, since_vc) do
    computed_delta_vc = Map.filter(vc, fn {replica_name, count} ->
      VectorClock.get(since_vc, replica_name) < count
    end)
    %Counter_GO{vc: computed_delta_vc}
  end

  def empty_state() do
    new()
  end

  def merge_states(%Counter_GO{} = c1, %Counter_GO{} = c2) do
    affect(c1, c2)
  end

  def merge_states(states) do
    Enum.reduce(states, empty_state(), fn %Counter_GO{vc: vc} = c, acc_c ->
      merge_states(acc_c, c)
    end)
  end

  @impl true
  def equal?(%Counter_GO{} = s1, %Counter_GO{} = s2) do
    s1.vc == s2.vc
  end

end
