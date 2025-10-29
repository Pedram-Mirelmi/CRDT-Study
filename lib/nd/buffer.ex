defmodule ND.ND_Buffer do
  alias ND.ND_Buffer
  defstruct crdts_deltas: %{} # structure crdt_key => %{origin => crdt_sub_state}

  def new() do
    %ND_Buffer{}
  end

  def store_effective_remote_deltas(%ND_Buffer{crdts_deltas: local_crdt_buffer}, %ND_Buffer{crdts_deltas: remote_crdt_buffer}, bp?) do
    new_crdts_deltas =
      Map.merge(local_crdt_buffer, remote_crdt_buffer, fn {_key_bin, crdt_type}, local_single_crdt_delta, remote_single_crdt_delta ->
        if bp? do # single_delta_delta : %{origin => single_crdt_origin_delta}
          Map.merge(local_single_crdt_delta, remote_single_crdt_delta, fn _origin, local_single_crdt_origin_delta, remote_single_crdt_origin_delta ->
            crdt_type.merge_state(local_single_crdt_origin_delta, remote_single_crdt_origin_delta)
          end)
        else # single_delta : simple crdt sub_state
          crdt_type.merge_state(local_single_crdt_delta, remote_single_crdt_delta)
        end
      end)
    %ND_Buffer{crdts_deltas: new_crdts_deltas}
  end

end
