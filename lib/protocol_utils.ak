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
    error_if_false(
      @"Transaction does not have the expected utxo",
      list.any(
        transaction.inputs,
        fn(
          /// Validate that the transaction has the expected utxo
          input,
        ) {
          input.output_reference == params.main_protocol_tx_out_ref
        },
      ),
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

pub fn validate_update(
  params: MainProtocolParams,
  protocol_policy_id: PolicyId,
  protocolDatum: MainProtocolDatum,
  transaction: Transaction,
) -> Bool {
  // Make sure that no protocol is being created (CreateProtocol not allowed)
  // Only one protocol should be in the inputs
  // Only one protocol should be in the outputs
  // Only one admin wallet should be allowed to update
  // New protocol parameters must be valid (Datum validation)

  expect Some((utxoInput, _)) =
    get_protocol_from_inputs(
      transaction,
      protocol_policy_id,
      params.main_protocol_id_tn,
      1,
    )
  expect Some((utxoOutput, _)) =
    get_protocol_from_outputs(
      transaction,
      protocol_policy_id,
      params.main_protocol_id_tn,
      1,
    )
  expect
    error_if_false(
      @"Admin wallet not found in the transaction",
      is_admin_auth(transaction, protocolDatum),
    )
  expect
    error_if_false(
      @"Transaction cannot mint during UpdateProtocol",
      quantity_of(
        transaction.mint,
        protocol_policy_id,
        params.main_protocol_id_tn,
      ) == 0,
    )
  // Value must remain unchanged
  expect
    error_if_false(
      @"Output value must match input value",
      utxoInput.value == utxoOutput.value,
    )
  and {
    !list.is_empty(protocolDatum.admin_wallets),
    !bytearray.is_empty(protocolDatum.oracle_policy_id),
  }
  // protocolDatum.commission_percent > 0,
}

/// Validate that the utxo to update is consumed in the transaction
/// Validate that the utxo updated is being created and that the token is transfered
/// Validate that some admin in the list has signed the transaction
/// Validate that there's no minting during the transaction
/// Validate that the new datum is valid
/// Validate that same protocol is not consumed in the inputs
/// Validate that the protocol is created in the outputs and only one NFT token is minted
/// Multiple validations:
/// - Admin wallets must not be empty
/// - Oracle policy ID must not be empty
/// - Commission percent must be greater than 0
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

fn is_admin_auth(
  transaction: Transaction,
  protocolDatum: MainProtocolDatum,
) -> Bool {
  let is_admin_signed =
    list.any(
      protocolDatum.admin_wallets,
      fn(admin) { list.has(transaction.extra_signatories, admin) },
    )

  is_admin_signed
}

// If a test fails, immediately crash the script with an error message. This is useful
// when some side-effect needs to be verified before continuing with the main function.
pub fn error_if_false(msg: String, predicate: Bool) {
  if !predicate {
    fail msg
  } else {
    predicate
  }
}
