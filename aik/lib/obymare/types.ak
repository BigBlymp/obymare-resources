use aiken/transaction.{OutputReference}
use aiken/transaction/credential.{Credential}

pub type Er2Red {
  o_num: Int,
  o_denom: Int,
  u_num: Int,
  u_denom: Int,
}

pub type ErpParams =
  OutputReference

pub type ErpDat =
  Credential

pub type Erp3Red {
  Erp3Update(Int, Int)
  Erp3Close
}

pub type Erp2Red {
  Erp2Init
  Erp2Burn
}

pub type MParams {
  erp_hash: ByteArray,
  obyiii_hash: ByteArray,
}

pub type M3Red =
  Data

pub type Tag =
  ByteArray

pub type M2Red {
  Open(OpenParams)
  Adjust(AdjustParams)
  Close(Tag)
  Redeem(Tag)
  Lqd(Tag)
  Lwc(LwcParams)
  Tidy
  Burn
}

pub type OpenParams {
  seed: OutputReference,
  cont_idx: Int,
  treas_idx: Int,
}

pub type AdjustParams {
  tag: ByteArray,
  auth_idx: Int,
  cont_idx: Int,
  treas_idx: Int,
}

pub type LwcParams {
  tag: ByteArray,
  treas_idx: Int,
}

pub type Debt =
  Int

pub type MDat {
  Position(Debt)
  Treasury
}
