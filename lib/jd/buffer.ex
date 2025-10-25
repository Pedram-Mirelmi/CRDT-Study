defmodule JD.Buffer do
  alias JD.Buffer
  defstruct bp_optimized_data: %{}, regular_data: %{}



  def new() do
    %JD.Buffer{}
  end


  def get(this, bp?) do
    if bp? do
      this.bp_optimized_data
    else
      this.regular_data
    end
  end

  def merge_buffer(this, other, bp?) do
    if bp? do
      %Buffer{ this | bp_optimized_data: merge_if_bp_optimized(this, other)}
    else
      %Buffer{ this | regular_data: merge_if_regular(this, other)}
    end
  end

  def remove_origin(this, origin_neighbour) do
    new_bp_optimized_data = Enum.reduce(this.bp_optimized_data, %{}, fn {key, single_crdt_delta_group}, acc ->
      Map.put(acc, key, Map.delete(single_crdt_delta_group, origin_neighbour))
    end)
    %Buffer{this | bp_optimized_data: new_bp_optimized_data}
  end


  defp merge_if_bp_optimized(this, other) do
    Map.merge(this.bp_optimized_data, other.bp_optimized_data, fn _key, val1, val2 ->
      Map.merge(val1, val2, fn _origin, set1, set2 ->
        MapSet.union(set1, set2)
      end)
    end)
  end

  defp merge_if_regular(this, other) do
    Map.merge(this.regular_data, other.regular_data, fn _key, set1, set2 ->
      MapSet.union(set1, set2)
    end)
  end

end
