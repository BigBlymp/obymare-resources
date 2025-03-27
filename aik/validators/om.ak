use aiken/dict
use aiken/list
use aiken/transaction.{Input, Mint, OutputReference, ScriptContext, Transaction}
use aiken/transaction/value
use obymare/constants as c
use obymare/tokens

pub type Om2Red {
  Om2Mint
  Om2Burn
}

validator(params: OutputReference) {
  pub fn om2(red: Om2Red, ctx: ScriptContext) {
    let ScriptContext { transaction, purpose } = ctx
    trace @"2Args: purpose is mint only"
    expect Mint(own_pid) = purpose
    let Transaction { inputs, mint, .. } = transaction
    expect [Pair(obyiii_asset_name, obyiii_amt)] =
      dict.to_pairs(value.tokens(value.from_minted_value(mint), own_pid))
    when red is {
      Om2Mint -> {
        trace @"**Om2Mint**:"
        trace @"1. `OmParams` is spent"
        expect list.any(inputs, fn(i) { i.output_reference == params })
        trace @"2. Own mint is `[(obyiii, TOTAL_OBYIII)]`"
        expect tokens.obyiii() == obyiii_asset_name
        expect c.total_obyiii() == obyiii_amt
        True
      }
      Om2Burn -> {
        trace @"**Om2Burn**:"
        trace @"1. Own mint has only negative quantities"
        obyiii_amt < 0
      }
    }
  }
}
