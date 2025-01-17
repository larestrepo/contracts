use aiken/crypto.{ScriptHash}
// 1. Main Protocol Contract

use cardano/assets.{PolicyId}
use cardano/transaction.{Transaction}
use protocol_utils.{validate_create, validate_update}
use types.{
  CreateProtocol, MainProtocolDatum, MainProtocolParams, MainProtocolRedeemer,
  UpdateProtocol,
}

validator main_protocol_validator(params: MainProtocolParams) {
  spend(
    datum: Option<MainProtocolDatum>,
    redeemer: MainProtocolRedeemer,
    script_hash: ScriptHash,
    transaction: Transaction,
  ) {
    let protocol_policy_id = script_hash
    when datum is {
      Some(protocolDatum) ->
        when redeemer is {
          CreateProtocol -> False
          UpdateProtocol ->
            validate_update(
              params,
              protocol_policy_id,
              protocolDatum,
              transaction,
            )
        }
      None -> False
    }
  }

  mint(
    redeemer: MainProtocolRedeemer,
    protocol_policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      CreateProtocol -> validate_create(params, protocol_policy_id, transaction)
      _ -> False
    }
  }

  else(_) {
    fail @"unsupported purpose"
  }
}
