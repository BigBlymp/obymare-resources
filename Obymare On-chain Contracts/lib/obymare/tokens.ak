use aiken/builtin.{serialise_data}
use aiken/bytearray as ba
use aiken/hash.{blake2b_256}
use aiken/transaction.{OutputReference}

pub fn validity_token_pref() -> ByteArray {
  #"000de140"
}

pub fn auth_token_pref() -> ByteArray {
  #"000643b0"
}

pub fn obyusd() -> ByteArray {
  "OBYUSD"
}

pub fn obyiii() -> ByteArray {
  "OBYIII"
}

pub fn erp_label() -> ByteArray {
  "erp"
}

pub fn user_label() -> ByteArray {
  "obymare"
}

pub fn erp_validity_token() {
  ba.concat(validity_token_pref(), erp_label())
}

pub fn erp_auth_token() {
  ba.concat(auth_token_pref(), erp_label())
}

pub fn user_validity_pref() {
  ba.concat(validity_token_pref(), user_label())
}

pub fn user_auth_pref() {
  ba.concat(auth_token_pref(), user_label())
}

pub fn user_pref_len() {
  ba.length(ba.concat(auth_token_pref(), user_label()))
}

pub fn user_validity_token(tag: ByteArray) {
  ba.concat(user_validity_pref(), tag)
}

pub fn user_auth_token(tag: ByteArray) {
  ba.concat(user_auth_pref(), tag)
}

pub fn get_tag(an: ByteArray) {
  ba.drop(an, user_pref_len())
}

/// Note that tn limits the combined length of label and tag.
pub fn mk_tag(oref: OutputReference) -> ByteArray {
  oref
    |> serialise_data()
    |> blake2b_256()
    |> ba.take(20)
}
