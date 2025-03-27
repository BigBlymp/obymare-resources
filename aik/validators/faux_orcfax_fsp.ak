//// SOURCE : adapted from https://github.com/orcfax/orcfax-examples
use aiken/dict
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Mint, Output, ScriptContext, Spend, Transaction,
}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value
use orcfax/tokens

pub type Fsp2 {
  FspMint
  FspBurn
}

pub type Fsp3 {
  FspUpdate
  FspClose
}

validator(_params: ByteArray) {
  fn two(red: Fsp2, ctx: ScriptContext) {
    let ScriptContext { transaction, purpose } = ctx
    expect Mint(own_hash) = purpose
    let Transaction { mint, outputs, .. } = transaction
    let own_mint =
      mint
        |> value.from_minted_value()
        |> value.tokens(own_hash)
        |> dict.to_pairs()
    when red is {
      FspMint -> {
        expect [Pair(auth, 1), Pair(vali, 1)] = own_mint
        expect and {
            auth == tokens.fsp_auth(),
            vali == tokens.fsp_vali(),
          }
        expect Some(Output {
          address: Address {
            payment_credential: ScriptCredential(cont_hash),
            ..
          },
          value: cont_value,
          datum: InlineDatum(cont_idat),
          reference_script: None,
        }) = outputs |> list.at(0)
        expect cont_hash == own_hash
        expect [_, (h, tn, 1)] = cont_value |> value.flatten()
        expect and {
            h == own_hash,
            tn == tokens.fsp_vali(),
          }
        expect _dat: ByteArray = cont_idat
        True
      }
      FspBurn -> {
        expect [Pair(auth, -1), Pair(vali, -1)] = own_mint
        and {
          auth == tokens.fsp_auth(),
          vali == tokens.fsp_vali(),
        }
      }
    }
  }

  fn three(_dat: ByteArray, red: Fsp3, ctx: ScriptContext) {
    expect ScriptContext {
      transaction: Transaction { inputs, outputs, mint, .. },
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
    when red is {
      FspUpdate -> {
        expect
          outputs
            |> list.any(
                fn(o) {
                  ( o.value |> value.quantity_of(own_hash, tokens.fsp_auth()) ) == 1
                },
              )
        expect Some(Output {
          value: cont_value,
          datum: InlineDatum(cont_idat),
          reference_script: None,
          .. 
        }) = outputs |> list.find( fn(o) {o.address.payment_credential == own_cred} )
        expect [_, (h, tn, 1)] = cont_value |> value.flatten()
        expect and {
            h == own_hash,
            tn == tokens.fsp_vali(),
          }
        expect _dat: ByteArray = cont_idat
        True
      }
      FspClose -> {
        let own_mint =
          mint
            |> value.from_minted_value
            |> value.tokens(own_hash)
            |> dict.to_pairs()
        expect [Pair(auth, -1), Pair(vali, -1)] = own_mint
        and {
          auth == tokens.fsp_auth(),
          vali == tokens.fsp_vali(),
        }
      }
    }
  }
}
