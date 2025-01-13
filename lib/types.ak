use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{PolicyId}
// Protocol Types

use cardano/transaction.{OutputReference}

/// Protocol parameters to create unique contract addresses based on utxo reference and token name
pub type MainProtocolParams {
  /// OutputReference that must be consumed when minting the Main Protocol ID token
  main_protocol_tx_out_ref: OutputReference,
  /// Main Protocol ID token name that will be minted
  main_protocol_id_tn: ByteArray,
}

/// Datum: Admin and protocol details
pub type MainProtocolDatum {
  /// List of admin wallets that can update protocol parameters
  admin_wallets: List<VerificationKeyHash>,
  /// Oracle policy ID that will be used to refer to prices and other info
  oracle_policy_id: PolicyId,
  /// Commission percentage that will be charged on token purchases
  commission_percent: Int,
}

/// Redeemer: Admin actions
pub type MainProtocolRedeemer {
  /// Initialize protocol by minting Protocol ID token
  CreateProtocol
  /// Update protocol parameters while maintaining Protocol ID token
  UpdateProtocol
}
