defmodule Crdts.CRDT do
  @moduledoc """
  Documentation for `CRDT`.

  This module defines types, callbacks for behaviours and the functions that use them.
  It ensures only valid CRDTs are created.
  New updates are created by local downstream operations and upon being received applied as updates.
  The require_state_downstream callback states if the crdt's local state is needed to create the downstream effect / update or not.

  Naming pattern for CRDTs: <type>_<semantics>_<OB|SB>

  CRDT provided:
  Counter_PN_OP: PN-Counter aka Positive Negative Counter
  Set_AW_OP: Add-wins set, to be completed, see ex6
  """

# ToDo: Improve type spec
alias Crdts.Counter_GO
alias Crdts.Set_GO_ND
alias Crdts.Set_GO_SB
alias Crdts.Set_GO_JD
alias Crdts.Set_GO_BD


  @type crdt_type ::
    Set_GO_ND
    | Set_GO_SB
    | Set_GO_JD
    | Set_GO_BD
    | Counter_GO


  @type crdt ::
    %Set_GO_SB{}
    | %Set_GO_ND{}
    | %Set_GO_JD{}
    | %Set_GO_BD{}
    | %Counter_GO{}


  @type operation :: atom()
  @type args :: list(term()) | tuple() # type for map
  @type internal_update :: {operation(), args()}

  @type internal_effect :: term()
  @type value :: term()
  @type reason :: term()



  @callback new() :: crdt()
  @callback value(crdt()) :: value()
  @callback downstream_effect(crdt(), internal_update()) :: internal_effect()
  # @callback valid_effect?(internal_effect()) :: boolean()
  @callback affect(crdt(), internal_effect()) :: crdt()
  @callback causes_inflation?(crdt(), internal_effect()) :: boolean()
  # @callback valid_update?(internal_update()) :: boolean()

  @callback equal?(crdt(), crdt()) :: boolean()

  # ToDo: Add new types as needed
  defguard is_valid_type?(type)
  when
  (type == Set_GO_SB)
  or (type == Set_GO_ND)
  or (type == Set_GO_JD)
  or (type == Set_GO_BD)
  or (type == Counter_GO)


  defguard is_valid_atom_type?(atom)
  when
  (atom == :set_go_sb)
  or (atom == :set_go_nd)

  def valid_atom_type(atom) do
    is_valid_atom_type?(atom)
  end

  def crdt_type(atom) do
    case atom do
      :set_go_sb -> Set_GO_SB
      :set_go_nd -> Set_GO_ND
      :set_go_jd -> Set_GO_JD
      :set_go_bd -> Set_GO_BD
      _ -> raise "Invalid crdt atom #{inspect(atom)}"
    end
  end


  def new(type) when is_valid_type?(type) do
    type.new()
  end

  def value(type, crdt) when is_valid_type?(type) do
    type.value(crdt)
  end

  def downstream_effect(type, crdt, update) when is_valid_type?(type) do
    type.downstream_effect(crdt, update)
  end

  def valid_effect?(type, effect) when is_valid_type?(type) do
    type.valid_effect?(effect)
  end

  def valid_update?(type, update) when is_valid_type?(type) do
    type.valid_update?(update)
  end

  def affect(type, crdt, effect) when is_valid_type?(type) do
    type.affect(crdt, effect)
  end

  def equal?(type, crdt1, crdt2) when is_valid_type?(type) do
    type.equal?(crdt1, crdt2)
  end

  def causes_inflation?(type, crdt, effect) when is_valid_type?(type) do
    type.causes_inflation?(crdt, effect)
  end

  @spec to_binary(crdt()) :: binary()
  def to_binary(crdt) do
    :erlang.term_to_binary(crdt)
  end

  @spec from_binary(binary()) :: {:ok, crdt()} | {:error, reason()}
  def from_binary(binary) do
    try do
      {:ok, :erlang.binary_to_term(binary)}
    rescue
      _ -> {:error, "Invalid binary format for CRDT"}
    end
  end
end
