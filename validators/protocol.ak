// 1. Main Protocol Contract

use cardano/assets.{PolicyId}
use cardano/transaction.{Transaction}
use protocol_utils.{validate_create}
use types.{CreateProtocol, MainProtocolParams, MainProtocolRedeemer}

validator main_protocol_validator(params: MainProtocolParams) {
  //   spend(
  //       datum: Option<types.MainProtocolDatum>,
  //       redeemer: types.MainProtocolRedeemer,
  //       script_hash: ScriptHash,
  //       transaction: Transaction,
  //   ) {

  //       expect Some(protocolDatum: MainProtocolDatum) = datum
  //       when redeemer is {
  //           CreateProtocol -> False
  //       }
  //       todo @"spend logic goes here"

  //   assert(main_protocol_datum.commission_percent >= 0, "Invalid commission percentage")
  // }

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
