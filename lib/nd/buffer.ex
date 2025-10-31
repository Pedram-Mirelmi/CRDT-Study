defmodule ND.ND_Buffer do
  alias ND.ND_Buffer
  defstruct crdts_deltas: %{} # structure crdt_key => %{origin => crdt_sub_state}

  def new() do
    %ND_Buffer{}
  end

  @doc """
    regular_delta_buffer & remote_crdt_buffer:
    %{
      key => <crdt_substate>
    }


  """
  def store_effective_remote_deltas(%ND_Buffer{crdts_deltas: regular_delta_buffer}, remote_crdt_buffer, nil) do
    new_crdts_deltas =
      Enum.reduce(remote_crdt_buffer, regular_delta_buffer, fn {{_key_bin, crdt_type} = key, remote_single_crdt_delta}, acc_regular_delta_buffer ->
        local_single_crdt_delta = Map.get(acc_regular_delta_buffer, key, crdt_type.empty_state())
        updated_single_crdt_delta = crdt_type.merge_states(local_single_crdt_delta, remote_single_crdt_delta)
        Map.put(acc_regular_delta_buffer, key, updated_single_crdt_delta)
      end)
    %ND_Buffer{crdts_deltas: new_crdts_deltas}
  end


  @doc """
    bp_optimized_delta_buffer:
    %{
      key => %{
        origin1 => <crdt_substate>
      }
    }

    remote_crdt_buffer:
    %{
      key => <crdt_substate>
    }
  """
  def store_effective_remote_deltas(%ND_Buffer{crdts_deltas: bp_optimized_delta_buffer}, remote_crdt_buffer, origin) do
    new_crdts_deltas =
      Enum.reduce(remote_crdt_buffer, bp_optimized_delta_buffer, fn {{_key_bin, crdt_type} = key, remote_single_crdt_delta}, acc_bp_optimized_delta_buffer ->
        local_single_crdt_deltas = Map.get(acc_bp_optimized_delta_buffer, key, %{})
        local_delta_from_this_origin = Map.get(local_single_crdt_deltas, origin, crdt_type.empty_state())
        updated_delta_from_this_origin = crdt_type.merge_states(local_delta_from_this_origin, remote_single_crdt_delta)
        updated_local_single_crdt_delta = Map.put(local_single_crdt_deltas, origin, updated_delta_from_this_origin)
        Map.put(acc_bp_optimized_delta_buffer, key, updated_local_single_crdt_delta)
      end)
    %ND_Buffer{crdts_deltas: new_crdts_deltas}
  end


   @doc """
    bp_optimized_delta_buffer:
    %{
      key => %{
        origin1 => <crdt_substate>
      }
    }
  """
  def remove_deltas_from_origin(%ND_Buffer{crdts_deltas: bp_optimized_delta_buffer}, origin_neighbour) do
    Enum.reduce(bp_optimized_delta_buffer, %{}, fn {{_key_bin, crdt_type} = key, single_crdt_delta_map}, acc ->
      removed_origin_deltas_map = Map.delete(single_crdt_delta_map, origin_neighbour)
      if Kernel.map_size(removed_origin_deltas_map) != 0 do
        merged_deltas = crdt_type.merge_states(Map.values(removed_origin_deltas_map))
        Map.put(acc, key, merged_deltas)
      else
        acc
      end
    end)
  end

end
