//// SOURCE : adapted from https://github.com/orcfax/orcfax-examples

use aiken/dict
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Mint, Output, ScriptContext, Spend, Transaction,
}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value
use orcfax/tokens
use orcfax/types as orcfax_t
use orcfax/rational.{ Rational, RationalStatement, RationalFsDat }

pub type Fs2 {
  FsMint
  FsBurn
}

validator(_params: ByteArray) {
  fn two(red: Fs2, ctx: ScriptContext) {
    trace @"Two Args: Purpose is `Mint(own_hash)`"
    let ScriptContext { transaction, purpose } = ctx
    expect Mint(own_hash) = purpose
    let Transaction { mint, outputs, .. } =
      transaction
    let own_mint =
      mint
        |> value.from_minted_value()
        |> value.tokens(own_hash)
        |> dict.to_pairs()
    when red is {
      FsMint -> {
        expect [Pair(tn, cnt)] = own_mint
        expect tn == tokens.fs()
        let own_cred = ScriptCredential(own_hash)
        let vali_triple = (own_hash, tn, 1)
        expect ( outputs |> list.length ) >= cnt
        outputs
          |> list.take(cnt)
          |> list.map(
              fn(o) {
                expect Output {
                  address: Address { payment_credential: o_cred, .. },
                  value: o_value,
                  datum: InlineDatum(o_idat),
                  reference_script: None,
                } = o
                expect o_cred == own_cred
                expect [_, vali_triple_] = o_value |> value.flatten()
                expect vali_triple_ == vali_triple
                expect _o_dat: orcfax_t.FsDat<Data> = o_idat
                True
              },
            )
          |> list.all(fn(t) { t })
      }
      FsBurn -> {
        expect [Pair(_, amt)] = own_mint
        expect amt < 0
        outputs
          |> list.all(
              fn(o) {
                (
                  o.value
                    |> value.tokens(own_hash)
                    |> dict.to_pairs
                    |> list.length
                ) == 0
              },
            )
      }
    }
  }

  fn three(_dat: Data, _red: Data, ctx: ScriptContext) {
    expect ScriptContext {
      transaction: Transaction { inputs, mint, .. },
      purpose: Spend(own_oref),
    } = ctx
    expect Some(Input {
      output: Output {
        address: Address { payment_credential: own_cred, .. },
        ..
      },
      ..
    }) = inputs |> list.find(fn(i) { i.output_reference == own_oref })
    expect ScriptCredential(own_hash) = own_cred
    expect [Pair(_, amt)] =
      mint
        |> value.from_minted_value
        |> value.tokens(own_hash)
        |> dict.to_pairs()
    amt < 0
  }
}

validator {
  fn rational(_ : Rational, _ctx : Data) {
    True
  }
}
validator {
  fn rational_fs_dat(_ : RationalFsDat, _ctx : Data) {
    True
  }
}
validator {
  fn rational_statement(_ : RationalStatement, _ctx : Data) {
    True
  }
}
