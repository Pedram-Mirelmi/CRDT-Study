defmodule JD.JD_Buffer do
  require Logger
  alias JD.JD_Buffer
  defstruct crdts_deltas: %{}

  def new() do
    %JD.JD_Buffer{}
  end

  @doc """
  regular_delta_buffer:
  %{
    key => MapSet.new(["a", "b", ...])
  }
  """
  def store_effective_remote_deltas(%JD_Buffer{crdts_deltas: regular_delta_buffer}, remote_crdt_buffer, nil) do
    new_crdts_deltas =
      Enum.reduce(remote_crdt_buffer, regular_delta_buffer, fn {key, remote_single_crdt_jds_set}, acc_regular_delta_buffer ->
        local_single_crdt_delta_jds = Map.get(acc_regular_delta_buffer, key, MapSet.new())

        updated_single_crdt_delta_jds = MapSet.union(local_single_crdt_delta_jds, remote_single_crdt_jds_set)

        Map.put(acc_regular_delta_buffer, key, updated_single_crdt_delta_jds)
      end)
    %JD_Buffer{crdts_deltas: new_crdts_deltas}
  end


  @doc """
  bp_optimized_delta_buffer:
  %{
    key => MapSet.new([{origin1, "a"}, {origin2, "b"}, ...])
  }


  remote_crdt_buffer:           we know all are from `origin`
  %{
    key => MapSet.new(["a", "b", ...])
  }

  """
  def store_effective_remote_deltas(%JD_Buffer{crdts_deltas: bp_optimized_delta_buffer}, remote_crdt_buffer, origin) do
    new_crdts_deltas =
      Enum.reduce(remote_crdt_buffer, bp_optimized_delta_buffer, fn {key, remote_single_crdt_jds_set}, acc_bp_optimized_delta_buffer ->
        local_single_crdt_delta_jds = Map.get(acc_bp_optimized_delta_buffer, key, MapSet.new())
        entries_to_add = remote_single_crdt_jds_set |> Enum.map( &({origin, &1}) ) |> MapSet.new()

        updated_local_single_crdt_delta_jds = MapSet.union(local_single_crdt_delta_jds, MapSet.new(entries_to_add))

        Map.put(acc_bp_optimized_delta_buffer, key, updated_local_single_crdt_delta_jds)
      end)
    %JD_Buffer{crdts_deltas: new_crdts_deltas}
  end



  def remove_jds_from_origin(%JD_Buffer{crdts_deltas: bp_optimized_delta_buffer}, origin_neighbour) do
    Enum.reduce(bp_optimized_delta_buffer, %{}, fn {key, single_crdt_jds_set}, acc ->
      removed_origin_jds_set = Enum.reduce(single_crdt_jds_set, MapSet.new(), fn {origin, jd}, acc_jd_set ->
        if origin != origin_neighbour do
          MapSet.put(acc_jd_set, jd)
        else
          acc_jd_set
        end
      end) |> MapSet.new()
      if MapSet.size(removed_origin_jds_set) != 0 do
        Map.put(acc, key, removed_origin_jds_set)
      else
        acc
      end
    end)
  end

end
