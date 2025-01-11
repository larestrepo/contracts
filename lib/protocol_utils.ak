use aiken/collection/list
// 1. Main Protocol Contract

// use aiken/crypto.{ScriptHash}
use aiken/primitive/bytearray
// use aiken/primitives.int
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{InlineDatum, Output, Transaction}
use types.{MainProtocolDatum, MainProtocolParams}

pub fn validate_create(
  params: MainProtocolParams,
  protocol_policy_id: PolicyId,
  transaction: Transaction,
) -> Bool {
  expect
    list.any(
      transaction.inputs,
      fn(
        /// Validate that the transaction has the expected utxo
        input,
      ) {
        input.output_reference == params.main_protocol_tx_out_ref
      },
    )
  expect None =
    get_protocol_from_inputs(
      transaction,
      protocol_policy_id,
      params.main_protocol_id_tn,
      0,
    )
  expect Some((_, protocolDatum)) =
    get_protocol_from_outputs(
      transaction,
      protocol_policy_id,
      params.main_protocol_id_tn,
      1,
    )

  and {
    quantity_of(
      transaction.mint,
      protocol_policy_id,
      params.main_protocol_id_tn,
    ) == 1,
    !list.is_empty(protocolDatum.admin_wallets),
    !bytearray.is_empty(protocolDatum.oracle_policy_id),
    protocolDatum.commission_percent > 0,
  }
}

/// The protocol must not exists in the inputs
/// The protocol must exists in the outputs and it should be only one
/// Must mint exactly one Protocol ID token
/// Initial protocol parameters must be valid
fn get_protocol_from_inputs(
  transaction: Transaction,
  protocol_policy_id: PolicyId,
  protocol_id_tn: ByteArray,
  expect_count: Int,
) -> Option<(Output, MainProtocolDatum)> {
  let protocol_inputs =
    list.filter(
      transaction.inputs,
      fn(input) {
        quantity_of(input.output.value, protocol_policy_id, protocol_id_tn) == 1
      },
    )

  if list.length(protocol_inputs) == expect_count {
    when list.head(protocol_inputs) is {
      Some(input) ->
        when extract_protocol_datum(input.output) is {
          Some(protocolDatum) -> Some((input.output, protocolDatum))
          None -> None
        }
      _ -> None
    }
  } else {
    None
  }
}

fn get_protocol_from_outputs(
  transaction: Transaction,
  protocol_policy_id: PolicyId,
  protocol_id_tn: ByteArray,
  expect_count: Int,
) -> Option<(Output, MainProtocolDatum)> {
  let protocol_outputs =
    list.filter(
      transaction.outputs,
      fn(output) {
        quantity_of(output.value, protocol_policy_id, protocol_id_tn) == 1
      },
    )
  if list.length(protocol_outputs) == expect_count {
    when list.head(protocol_outputs) is {
      Some(output) ->
        when extract_protocol_datum(output) is {
          Some(protocolDatum) -> Some((output, protocolDatum))
          None -> None
        }
      _ -> None
    }
  } else {
    None
  }
}

fn extract_protocol_datum(output: Output) -> Option<MainProtocolDatum> {
  when output.datum is {
    InlineDatum(data) -> {
      expect datum: MainProtocolDatum = data
      Some(datum)
    }
    _ -> None
  }
}
