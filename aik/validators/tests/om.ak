use aiken/transaction.{
  Input, Mint, NoDatum, Output, OutputReference, ScriptContext, Transaction,
  TransactionId,
}
use aiken/transaction/credential.{Address, VerificationKeyCredential}
use aiken/transaction/value
use obymare/constants as c
use obymare/tokens
use om

pub const a_tx_id =
  #"963bde92a0d17c3bc5f6ff13f7b38f685ca9aa467febedbc2a95f1b4e932be4e"

pub const tx_index = 0

pub const a_hash = #"1b6b0667bbead0feba17027c752f684019385ee896c63191d1f3a519"

pub const b_hash = #"6d3f3840151bcea8c61f5e9fe3f96ba849d27ff1e4de2343a78e3812"

pub const c_hash = #"08fd067e6e10247d18d268bcb257cbdcf3e0adc4b89de2b50ba95420"

pub fn an_address(keyhash: ByteArray) {
  Address {
    payment_credential: VerificationKeyCredential(keyhash),
    stake_credential: None,
  }
}

test test_om() fail {
  let seed: OutputReference =
    OutputReference {
      transaction_id: TransactionId(a_tx_id),
      output_index: tx_index,
    }

  let output =
    Output {
      address: an_address(c_hash),
      value: value.zero(),
      datum: NoDatum,
      reference_script: None,
    }

  let input = Input { output_reference: seed, output }

  let val =
    value.from_asset(
      policy_id: a_hash,
      asset_name: tokens.obyiii(),
      quantity: c.total_obyiii() - 1,
    )

  let tx =
    Transaction {
      ..transaction.placeholder(),
      mint: value.to_minted_value(val),
      inputs: [input],
    }
  let ctx = ScriptContext { purpose: Mint(a_hash), transaction: tx }

  om.om2(seed, om.Om2Mint, ctx)?
}
