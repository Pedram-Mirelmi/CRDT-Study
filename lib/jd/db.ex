defmodule JD.JD_DB do
  alias JD.JD_DB
  alias Crdts.CRDT
  defstruct crdts: %{}



  def new() do
    %JD_DB{}
  end

  def get_crdt(db, {_key_bin, crdt_type} = key) do
    crdt = Map.get(db.crdts, key, CRDT.new(crdt_type))
    {crdt_type, crdt}
  end

  def compute_delta(db, buffer, bp?) do
    if bp? do
      compute_delta_if_bp_optimized(db, buffer.crdts_deltas)
    else
      compute_delta_if_regular(db, buffer.crdts_deltas)
    end
  end

  def apply_deltas(db, crdts_deltas, bp?) do
    new_crdts =
      if bp? do
        apply_deltas_if_bp_optimized(db, crdts_deltas)
      else
        apply_deltas_if_regular(db, crdts_deltas)
      end

    %JD_DB{db | crdts: new_crdts}
  end

  defp compute_delta_if_bp_optimized(%JD_DB{crdts: crdts}, deltas_map) do
    Enum.reduce(deltas_map, %{}, fn {{_key_bin, crdt_type} = key, origin_deltas_map}, acc_inflating_crdts_deltas ->
      local_crdt = Map.get(crdts, key, CRDT.new(crdt_type))

      strictly_inflating_crdt_deltas =
        Enum.reduce(origin_deltas_map, %{}, fn {origin, deltas_set}, acc_origin_deltas ->
          inflationary_deltas =
            MapSet.filter(deltas_set, fn delta ->
              CRDT.causes_inflation?(crdt_type, local_crdt, delta)
            end)

          if MapSet.size(inflationary_deltas) != 0 do
            Map.put(acc_origin_deltas, origin, inflationary_deltas)
          else
            acc_origin_deltas
          end
        end)

      if Kernel.map_size(strictly_inflating_crdt_deltas) != 0 do
        Map.put(acc_inflating_crdts_deltas, key, strictly_inflating_crdt_deltas)
      else
        acc_inflating_crdts_deltas
      end

    end)
  end

  defp compute_delta_if_regular(%JD_DB{crdts: crdts}, deltas_map) do
    Enum.reduce(deltas_map, %{}, fn {{_key_bin, crdt_type} = key, jd_set}, acc_strictly_inflating_crdts_deltas ->
      local_crdt = Map.get(crdts, key, CRDT.new(crdt_type))

      inflationary_deltas = MapSet.filter(jd_set, fn delta ->
        CRDT.causes_inflation?(crdt_type, local_crdt, delta)
      end)

      if MapSet.size(inflationary_deltas) != 0 do
        Map.put(acc_strictly_inflating_crdts_deltas, key, inflationary_deltas)
      else
        acc_strictly_inflating_crdts_deltas
      end
    end)


  end

  defp apply_deltas_if_bp_optimized(%JD_DB{crdts: crdts}, crdts_deltas) do
    Enum.reduce(crdts_deltas, crdts, fn {{_key_bin, crdt_type} = key, crdt_delta_group}, acc_crdts ->
      local_crdt = Map.get(acc_crdts, key, CRDT.new(crdt_type))

      updated_crdt = Enum.reduce(crdt_delta_group, local_crdt, fn {_origin, deltas_set}, acc_crdt ->
        Enum.reduce(deltas_set, acc_crdt, fn delta, acc_crdt_inner ->
          crdt_type.affect(acc_crdt_inner, delta)
        end)
      end)

      Map.put(acc_crdts, key, updated_crdt)
    end)
  end

  defp apply_deltas_if_regular(%JD_DB{crdts: crdts}, crdts_deltas) do
    Enum.reduce(crdts_deltas, crdts, fn {{_key_bin, crdt_type} = key, delta_set}, acc_crdts ->
      local_crdt = Map.get(acc_crdts, key, CRDT.new(crdt_type))
      updated_crdt = Enum.reduce(delta_set, local_crdt, fn delta, acc_crdt ->
        crdt_type.affect(acc_crdt, delta)
      end)
      Map.put(acc_crdts, key, updated_crdt)
    end)
  end

end
