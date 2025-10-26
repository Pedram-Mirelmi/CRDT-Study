defmodule JD.JD_Buffer do
  alias JD.JD_Buffer
  defstruct crdts_deltas: %{}



  def new() do
    %JD.JD_Buffer{}
  end


  def get(this) do
    this.crdts_deltas
  end

  def merge_buffer(this, other, bp?) do
    if bp? do
      %JD_Buffer{ this | crdts_deltas: merge_if_bp_optimized(this, other)}
    else
      %JD_Buffer{ this | crdts_deltas: merge_if_regular(this, other)}
    end
  end

  def remove_origin(this, origin_neighbour) do
    new_bp_optimized_data = Enum.reduce(this.crdts_deltas, %{}, fn {key, single_crdt_delta_group}, acc ->
      Map.put(acc, key, Map.delete(single_crdt_delta_group, origin_neighbour))
    end)
    %JD_Buffer{this | crdts_deltas: new_bp_optimized_data}
  end


  defp merge_if_bp_optimized(this, other) do
    Map.merge(this.crdts_deltas, other.crdts_deltas, fn _key, val1, val2 ->
      Map.merge(val1, val2, fn _origin, set1, set2 ->
        MapSet.union(set1, set2)
      end)
    end)
  end

  defp merge_if_regular(this, other) do
    Map.merge(this.crdts_deltas, other.crdts_deltas, fn _key, set1, set2 ->
      MapSet.union(set1, set2)
    end)
  end

end
