use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address, from_script, from_verification_key}
use cardano/assets.{PolicyId, Value, from_asset}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use protocol_utils.{validate_create}
use types

/// Section to initialize inputs and outputs for the protocol
type TestValuesProtocolMock {
  oracle_policy_id: PolicyId,
  protocol_policy_id: PolicyId,
  protocol_token_name: ByteArray,
  admin_wallets: List<VerificationKeyHash>,
  commission_percent: Int,
  utxo: OutputReference,
}

fn mock_transaction(
  inputs: List<Input>,
  reference_inputs: List<Input>,
  outputs: List<Output>,
  mint: Value,
  extra_signatories: List<VerificationKeyHash>,
) -> Transaction {
  Transaction {
    ..transaction.placeholder,
    inputs: inputs,
    reference_inputs: reference_inputs,
    outputs: outputs,
    mint: mint,
    extra_signatories: extra_signatories,
  }
}

// Initialize the mock values
fn mock_values() -> TestValuesProtocolMock {
  TestValuesProtocolMock {
    oracle_policy_id: #"2222222222222222222222222222222222222222222222222222222222222222",
    protocol_policy_id: #"1111111111111111111111111111111111111111111111111111111111111111",
    protocol_token_name: #"deadbeef",
    admin_wallets: [#"deadbeef"],
    commission_percent: 5,
    utxo: OutputReference {
      transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
      output_index: 0,
    },
  }
}

fn mock_protocol_params(
  values: TestValuesProtocolMock,
) -> types.MainProtocolParams {
  types.MainProtocolParams {
    main_protocol_tx_out_ref: values.utxo,
    main_protocol_id_tn: values.protocol_token_name,
  }
}

fn mock_protocol_datum(
  values: TestValuesProtocolMock,
) -> types.MainProtocolDatum {
  types.MainProtocolDatum {
    admin_wallets: values.admin_wallets,
    oracle_policy_id: values.oracle_policy_id,
    commission_percent: values.commission_percent,
  }
}

fn mock_address(values: TestValuesProtocolMock) -> Address {
  expect Some(key) = list.head(values.admin_wallets)
  from_verification_key(key)
}

test create_protocol() {
  let values = mock_values()
  let params = mock_protocol_params(values)
  let datum = mock_protocol_datum(values)
  let script_address = from_script(values.protocol_policy_id)

  // Create the reference input that must be consumed
  let input =
    Input {
      output_reference: values.utxo,
      output: Output {
        address: mock_address(values),
        value: from_asset(#"", #"", 1000000),
        datum: NoDatum,
        reference_script: None,
      },
    }

  // Create the output that is expected
  let output =
    Output {
      address: script_address,
      value: from_asset(
        values.protocol_policy_id,
        values.protocol_token_name,
        1,
      ),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  // value: from_asset(values.protocol_policy_id, values.protocol_token_name, 1),
  // datum: InlineDatum(datum),
  // reference_script: None,
  // Build the transaction
  let mint_value =
    from_asset(values.protocol_policy_id, values.protocol_token_name, 1)
  let transaction = mock_transaction([input], [], [output], mint_value, [])
  validate_create(params, values.protocol_policy_id, transaction)
}
