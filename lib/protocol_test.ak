use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/fuzz
use cardano/address.{Address, from_script, from_verification_key}
use cardano/assets.{
  PolicyId, Value, ada_asset_name, ada_policy_id, from_asset, from_asset_list,
  zero,
}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use protocol_utils.{validate_create, validate_update}
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

type TestValusUpdateProtocoMock {
  admin_wallets: List<VerificationKeyHash>,
  oracle_policy_id: PolicyId,
  commission_percent: Int,
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

// Initialize the mock values
fn mock_updateValues() -> TestValusUpdateProtocoMock {
  TestValusUpdateProtocoMock {
    oracle_policy_id: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
    admin_wallets: [#"deadbeef"],
    commission_percent: 2,
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
  admin_wallets,
  oracle_policy_id,
  commission_percent,
) -> types.MainProtocolDatum {
  types.MainProtocolDatum {
    admin_wallets,
    oracle_policy_id,
    commission_percent,
  }
}

fn mock_address(admin_wallets: List<VerificationKeyHash>) -> Address {
  expect Some(key) = list.head(admin_wallets)
  from_verification_key(key)
}

/// Test the create protocol function
test create_protocol() {
  let values = mock_values()
  let params = mock_protocol_params(values)
  let datum =
    mock_protocol_datum(
      values.admin_wallets,
      values.oracle_policy_id,
      values.commission_percent,
    )
  let script_address = from_script(values.protocol_policy_id)

  // Create the reference input that must be consumed
  let input =
    Input {
      output_reference: values.utxo,
      output: Output {
        address: mock_address(values.admin_wallets),
        value: from_asset(ada_policy_id, ada_asset_name, 1000000),
        datum: NoDatum,
        reference_script: None,
      },
    }

  // Create the output that is expected
  let output =
    Output {
      address: script_address,
      value: from_asset_list(
        [
          Pair(values.protocol_policy_id, [Pair(values.protocol_token_name, 1)]),
          Pair(ada_policy_id, [Pair(ada_asset_name, 1000000)]),
        ],
      ),
      datum: InlineDatum(datum),
      reference_script: None,
    }
  let mint_value =
    from_asset(values.protocol_policy_id, values.protocol_token_name, 1)
  let transaction = mock_transaction([input], [], [output], mint_value, [])
  validate_create(params, values.protocol_policy_id, transaction)
}

/// Test the update datum function
test update_protocol() {
  let old_values = mock_values()
  let new_values = mock_updateValues()
  let params = mock_protocol_params(old_values)

  let old_datum =
    mock_protocol_datum(
      old_values.admin_wallets,
      old_values.oracle_policy_id,
      old_values.commission_percent,
    )
  let new_datum =
    mock_protocol_datum(
      new_values.admin_wallets,
      new_values.oracle_policy_id,
      new_values.commission_percent,
    )
  let script_address = from_script(old_values.protocol_policy_id)

  // Create the reference input that must be consumed
  let input =
    Input {
      output_reference: old_values.utxo,
      output: Output {
        address: script_address,
        value: from_asset_list(
          [
            Pair(
              old_values.protocol_policy_id,
              [Pair(old_values.protocol_token_name, 1)],
            ),
            Pair(ada_policy_id, [Pair(ada_asset_name, 1000000)]),
          ],
        ),
        datum: InlineDatum(old_datum),
        reference_script: None,
      },
    }

  // Create the output that is expected
  let output =
    Output {
      address: script_address,
      value: from_asset_list(
        [
          Pair(
            old_values.protocol_policy_id,
            [Pair(old_values.protocol_token_name, 1)],
          ),
          Pair(ada_policy_id, [Pair(ada_asset_name, 1000000)]),
        ],
      ),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }

  let transaction =
    mock_transaction([input], [], [output], zero, old_values.admin_wallets)
  validate_update(params, old_values.protocol_policy_id, new_datum, transaction)
}

// Start fuzzer section to test create protocol params

fn generate_protocol_components_fuzzer() -> Fuzzer<
  (ByteArray, ByteArray, ByteArray, List<ByteArray>, Int, (ByteArray, Int)),
> {
  fuzz.map6(
    fuzz.bytearray(),
    fuzz.bytearray(),
    fuzz.bytearray(),
    fuzz.list_at_least(fuzz.bytearray(), 1),
    fuzz.int_between(1, 100),
    fuzz.map2(
      fuzz.bytearray(),
      fuzz.int_between(0, 10),
      fn(tx_id, id) { (tx_id, id) },
    ),
    fn(
      oracle_policy_id,
      protocol_policy_id,
      protocol_token_name,
      admin_wallets,
      commission_percent,
      utxo,
    ) {
      (
        oracle_policy_id,
        protocol_policy_id,
        protocol_token_name,
        admin_wallets,
        commission_percent,
        utxo,
      )
    },
  )
}

/// Fuzz test for the create protocol function
test create_protocol_fuzzer(
  values: (
    ByteArray,
    ByteArray,
    ByteArray,
    List<ByteArray>,
    Int,
    (ByteArray, Int),
  ) via generate_protocol_components_fuzzer(),
) {
  let (
    oracle_policy_id,
    protocol_policy_id,
    protocol_token_name,
    admin_wallets,
    commission_percent,
    (transaction_id, output_index),
  ) = values

  let mock_values =
    TestValuesProtocolMock {
      oracle_policy_id,
      protocol_policy_id,
      protocol_token_name,
      admin_wallets,
      commission_percent,
      utxo: OutputReference { transaction_id, output_index },
    }
  let params = mock_protocol_params(mock_values)
  let datum =
    mock_protocol_datum(admin_wallets, oracle_policy_id, commission_percent)
  let script_address = from_script(protocol_policy_id)

  // Create the reference input that must be consumed
  let input =
    Input {
      output_reference: mock_values.utxo,
      output: Output {
        address: mock_address(admin_wallets),
        value: from_asset(ada_policy_id, ada_asset_name, 1000000),
        datum: NoDatum,
        reference_script: None,
      },
    }

  // Create the output that is expected
  let output =
    Output {
      address: script_address,
      value: from_asset_list(
        [
          Pair(protocol_policy_id, [Pair(protocol_token_name, 1)]),
          Pair(ada_policy_id, [Pair(ada_asset_name, 1000000)]),
        ],
      ),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  // Build the transaction
  let mint_value =
    from_asset(
      mock_values.protocol_policy_id,
      mock_values.protocol_token_name,
      1,
    )
  let transaction = mock_transaction([input], [], [output], mint_value, [])
  let is_valid =
    validate_create(params, mock_values.protocol_policy_id, transaction)
  trace @"mock_values": mock_values
  trace @"transaction": transaction
  trace @"is_valid": is_valid

  expect is_valid == True
}
