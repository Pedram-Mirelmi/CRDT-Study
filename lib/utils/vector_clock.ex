defmodule Utility.VectorClock do
  require Logger
  alias Utility.VectorClock
  defstruct v: %{}


  @moduledoc """

  Each actual vc is represented as a map of pid -> integer.
  The integer is the number of events that have happened for that pid.
  The map is a sparse representation of the vector clock, so it only
  contains the pids that have been used.

  """

  @type t() :: %VectorClock{v: %{term() => integer()}}


  def new() do
    %VectorClock{}
  end

  def remove_entry(%VectorClock{v: map} = vc, entry) do
    new_map = Map.delete(map, entry)
    %VectorClock{vc | v: new_map}
  end

  def increment(%VectorClock{v: map}, p) do
    # if not Map.has_key?(map, p) do
    #   Logger.info("Incremented non-existing process #{inspect(p)} in vc")
    # end
    %VectorClock{v: map |> Map.update(p, 1, fn value -> value+1 end)}
    # map |> Map.update(p, 1, &(&1 + 1))
  end

  def get(%VectorClock{v: map}, p) do
    Map.get(map, p, 0)
  end

  def leq(%VectorClock{v: map1}, %VectorClock{v: map2}) do
    Enum.all?(map1, fn {k, v1} ->
      v2 = Map.get(map2, k, 0)
      v1 <= v2
    end)
  end

  def lt(%VectorClock{v: map1}, %VectorClock{v: map2}) do
    Enum.reduce_while(map1, false, fn {k, v1}, acc ->
      v2 = Map.get(map2, k, 0)
      cond do
        v1 > v2 ->
          {:halt, false}
        v1 < v2 ->
          {:cont, true}
        true ->
          {:cont, acc}
      end
    end)
  end

  def geq(%VectorClock{v: map1}, %VectorClock{v: map2}) do
    Enum.all?(map2, fn {k, v2} ->
      v1 = Map.get(map1, k, 0)
      v1 >= v2
    end)
  end

  def gt(%VectorClock{v: map1}, %VectorClock{v: map2}) do
    Enum.reduce_while(map2, false, fn {k, v2}, acc ->
      v1 = Map.get(map1, k, 0)
      cond do
        v1 < v2 ->
          {:halt, false}
        v1 > v2 ->
          {:cont, true}
        true ->
          {:cont, acc}
      end
    end)
  end



  def merge(%VectorClock{v: map1}, %VectorClock{v: map2}) do
    %VectorClock{v: Map.merge(map1, map2, fn _k, v1, v2 -> max(v1, v2) end)}
  end

  def equal?(%VectorClock{} = v1, %VectorClock{} = v2) do
    v1 == v2
  end

end


defimpl Inspect, for: Utility.VectorClock do
  require Logger
  alias Utility.VectorClock
  import Inspect.Algebra

  def inspect(%VectorClock{v: map}, _opts) do
    # Logger.debug("Inspecting VectorClock: #{inspect(map)}")
    binary =
      map
      |> Enum.map(fn {pid, count} -> "#{inspect(pid)}: #{count}" end)
      |> Enum.join(", ")
    concat(["[", binary, "]"])
  end
end
