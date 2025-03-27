use aiken/bytearray
use aiken/dict
use aiken/cbor
use aiken/list
use aiken/math
use aiken/pairs
use aiken/transaction.{
  Datum, InlineDatum, Input, Mint, Output, OutputReference, Redeemer,
  ScriptContext, ScriptPurpose, Spend, Transaction, WithdrawFrom,
}
use aiken/transaction/credential.{
  Address, Credential, Inline, ScriptCredential, StakeCredential,
}
use aiken/transaction/value
use obymare/constants as c
use obymare/tokens
use obymare/types as t

validator(params: t.MParams) {
  fn m2(red: t.M2Red, ctx: ScriptContext) {
    trace @"m2"
    let ScriptContext { transaction, purpose } = ctx
    when purpose is {
      Mint(own_hash) -> {
        trace @"2Args: purpose is mint"
        trace @"1. Withdraws includes own credential "
        let Transaction { withdrawals, .. } = transaction
        let own_cred = ScriptCredential(own_hash)
        expect Some(_) = pairs.get_first(withdrawals, Inline(own_cred))
        True
      }
      WithdrawFrom(Inline(own_cred)) -> {
        expect ScriptCredential(own_hash) = own_cred
        let t.MParams { erp_hash, obyiii_hash } = params
        let Transaction {
          inputs,
          mint,
          outputs,
          reference_inputs,
          redeemers,
          ..
        } = transaction
        let own_mint =
          dict.to_pairs(value.tokens(value.from_minted_value(mint), own_hash))
        trace @"Withdraw"
        when red is {
          t.Open(t.OpenParams { seed, cont_idx, treas_idx }) -> {
            trace @"1. Redeemer is `Open({oref, cont_idx, treas_idx})`"
            trace @"2. The seed, `oref`, is spent"
            expect list.any(inputs, fn(i) { i.output_reference == seed })
            trace @"3. The seed hashes to tag `tag = mk_tag(seed)`"
            let tag = tokens.mk_tag(seed)
            trace @"4. No own inputs"
            expect [] =
              list.filter(
                inputs,
                fn(i) { i.output.address.payment_credential == own_cred },
              )
            trace @"5. Output at index `cont_idx` "
            expect Some(cont_output) = list.at(outputs, cont_idx)
            expect Output {
              address: cont_address,
              value: cont_value,
              datum: cont_datum,
              reference_script : None,
            } = cont_output
            trace @"    1. Own payment address"
            expect own_cred == cont_address.payment_credential
            trace @"    2. Value is `cont_col` lovelace and validity token with tag `tag`"
            expect [(_, _, cont_col), (cont_hash, cont_name, _)] =
              value.flatten(cont_value)
            expect and {
                cont_hash == own_hash,
                cont_name == tokens.user_validity_token(tag),
              }
            trace @"    3. Datum is `Position(cont_debt)`"
            expect InlineDatum(cont_datum_inner) = cont_datum
            expect t.Position(cont_debt): t.MDat = cont_datum_inner
            trace @"    `cont_debt >= MIN_DEBT_AMOUNT`"
            expect cont_debt >= c.min_debt_amount()
            trace @"    `cont_debt <= MAX_DEBT_AMOUNT`"
            expect cont_debt <= c.max_debt_amount()
            trace @"6. Output at index `treas_idx` "
            expect Some(treas_output) = list.at(outputs, treas_idx)
            expect Output {
              address: treas_address,
              value: treas_value,
              datum: InlineDatum(treas_datum),
              reference_script: None,
            } = treas_output
            trace @"    1. Own payment address"
            expect treas_address == Address(own_cred, None)
            trace @"    2. Value is ada + `obyiii_fee` microobyiii "
            expect [_, (treas_hash, treas_name, obyiii_fee)] =
              value.flatten(treas_value)
            expect and {
                (treas_hash == obyiii_hash)?,
                (treas_name == tokens.obyiii())?,
              }
            trace @"    3. Datum is `Treasury`"
            expect t.Treasury: t.MDat = treas_datum
            trace @"7. Get exchange rates"
            let t.Er2Red { o_num, o_denom, u_num, u_denom,  } =
              get_er(erp_hash, reference_inputs, redeemers)
            trace @"8. `(cont_col, cont_debt)` respects MCR"
            expect above_mcr(u_num, u_denom, cont_col, cont_debt)
            trace @"9. `obyiii_fee` is sufficient fee"
            expect sufficient_fee(o_num, o_denom, u_num, u_denom, cont_debt, obyiii_fee)
            trace @"10. Own mint value is"
            expect [Pair(an0, qty0), Pair(an1, qty1), Pair(an2, qty2)] =
              own_mint
            trace @"    1. (auth token <tag>, 1)"
            trace @"    2. (validity token <tag>, 1)"
            trace @"    3. (obyusd, `cont_debt`)"
            expect and {
                an0 == tokens.user_auth_token(tag),
                qty0 == 1,
                an1 == tokens.user_validity_token(tag),
                qty1 == 1,
                an2 == tokens.obyusd(),
                qty2 == cont_debt,
              }
            True
          }
          t.Adjust(t.AdjustParams { tag, auth_idx, cont_idx, treas_idx }) -> {
            trace @"1. Redeemer is `Adjust({tag, auth_idx, cont_idx, treas_idx})`"
            trace @"2. Own inputs is `[own_input]` "
            expect [own_input] =
              list.filter(
                inputs,
                fn(i) { i.output.address.payment_credential == own_cred },
              )
            trace @"3. Extract `(own_col, own_debt)` from `own_input`"
            let (own_col, own_debt) = extract_position(own_input.output)
            trace @"4. `auth_idx` output is auth output"
            expect Some(auth_output) = list.at(outputs, auth_idx)
            trace @"    1. Value has auth token with tag `tag`"
            expect
              value.quantity_of(
                auth_output.value,
                own_hash,
                tokens.user_auth_token(tag),
              ) == 1
            trace @"5. `cont_idx` output is continuing output"
            expect Some(cont_output) = list.at(outputs, cont_idx)
            expect Output {
              address: cont_address,
              value: cont_value,
              datum: cont_datum,
              reference_script: None,
            } = cont_output
            trace @"    1. Own payment address"
            expect own_cred == cont_address.payment_credential
            trace @"    2. Value is `cont_col` lovelace and validity token with tag `tag`"
            expect [(_, _, cont_col), (cont_hash, cont_name, _)] =
              value.flatten(cont_value)
            expect and {
                cont_hash == own_hash,
                cont_name == tokens.user_validity_token(tag),
              }
            trace @"    3. Datum is `Position(cont_debt)`"
            expect InlineDatum(cont_datum_inner) = cont_datum
            expect t.Position(cont_debt): t.MDat = cont_datum_inner
            trace @"    `cont_debt >= MIN_DEBT_AMOUNT`"
            expect cont_debt >= c.min_debt_amount()
            trace @"    `cont_debt <= MAX_DEBT_AMOUNT`"
            expect cont_debt <= c.max_debt_amount()
            trace @"6. Calculate `del_col = cont_col - own_col` and `del_debt = cont_debt - own_debt`"
            let del_col = cont_col - own_col
            let del_debt = cont_debt - own_debt
            trace @"7. If either `del_col != 0` or `del_debt > 0`, then"
            expect
              if del_col != 0 || del_debt > 0 {
                trace @"    1. Get exchange rates"
                let t.Er2Red { u_num, u_denom, o_num, o_denom } =
                  get_er(erp_hash, reference_inputs, redeemers)
                trace @"    2. If either `del_col < 0` or `del_debt > 0`, then `(cont_col, cont_debt)` respects MCR"
                expect
                  if del_col < 0 || del_debt > 0 {
                    above_mcr(u_num, u_denom, cont_col, cont_debt)
                  } else {
                    True
                  }
                trace @"    3. If `del_debt > 0` then `treas_idx` output is treasury output"
                if del_debt > 0 {
                  expect Some(treas_output) = list.at(outputs, treas_idx)
                  expect Output {
                    address: treas_address,
                    value: treas_value,
                    datum: treas_datum,
                    reference_script: None
                  } = treas_output
                  trace @"        1. Own payment address"
                  expect own_cred == treas_address.payment_credential
                  trace @"        2. Value is ada + `obyiii_fee` microobyiii "
                  expect [_, (treas_hash, treas_name, obyiii_fee)] =
                    value.flatten(treas_value)
                  expect and {
                      treas_hash == obyiii_hash,
                      treas_name == tokens.obyiii(),
                    }
                  trace @"        `obyiii_fee` is sufficient"
                  expect sufficient_fee(o_num, o_denom, u_num, u_denom, del_debt, obyiii_fee)
                  trace @"        3. Datum is `Treasury`"
                  expect InlineDatum(treas_datum_inner) = treas_datum
                  expect t.Treasury: t.MDat = treas_datum_inner
                  True
                } else {
                  True
                }
              } else {
                True
              }
            trace @"8. Own mint value is"
            expect
              if del_debt != 0 {
                trace @"    1. If `del_debt != 0` then [(obyusd, `del_debt`)]"
                expect [Pair(mint_name, mint_qty)] = own_mint
                expect and {
                    mint_name == tokens.obyusd(),
                    mint_qty == del_debt,
                  }
                True
              } else {
                trace @"    2. Else is `[]`"
                expect [] == own_mint
                True
              }
            True
          }
          t.Close(tag) -> {
            trace @"1. Redeemer is `Close(tag)`"
            trace @"2. Own inputs is `[own_input]` "
            expect [own_input] =
              list.filter(
                inputs,
                fn(i) { i.output.address.payment_credential == own_cred },
              )
            trace @"3. Extract `own_debt` from `own_input`"
            let (_, own_debt) = extract_position(own_input.output)
            expect
              if own_debt == 0 {
                trace @"4. Own mint value is"
                expect [Pair(an0, qty0), Pair(an1, qty1)] = own_mint
                trace @"    1. (auth token `tag`, -1)"
                trace @"    2. (validity token `tag`, -1)"
                expect and {
                    an0 == tokens.user_auth_token(tag),
                    qty0 == -1,
                    an1 == tokens.user_validity_token(tag),
                    qty1 == -1,
                  }
                True
              } else {
                trace @"4. Own mint value is"
                expect [Pair(an0, qty0), Pair(an1, qty1), Pair(an2, qty2)] =
                  own_mint
                trace @"    1. (auth token `tag`, -1)"
                trace @"    2. (validity token `tag`, -1)"
                trace @"    3. (obyusd, `-own_debt`)"
                expect and {
                    an0 == tokens.user_auth_token(tag),
                    qty0 == -1,
                    an1 == tokens.user_validity_token(tag),
                    qty1 == -1,
                    an2 == tokens.obyusd(),
                    qty2 == -own_debt,
                  }
                True
              }
            True
          }
          t.Redeem(only_tag) -> {
            trace @"1. Redeemer is `Redeem(only_tag)`"
            let only_val_tn = tokens.user_validity_token(only_tag)
            trace @"2. Calculate input condensate. For each own inputs"
            trace @"    1. Input is a position, and extract `tag`, `col`, and `debt`"
            let input_condensate =
              list.foldr(
                inputs,
                [],
                fn(
                  curr: Input,
                  acc: List<(ByteArray, Option<StakeCredential>, Int, Int)>,
                ) {
                  let Output { address, datum, value, .. } = curr.output
                  if address.payment_credential != own_cred {
                    acc
                  } else {
                    let debt = get_debt(datum)
                    expect [(_, _, col), (val_hash, val_tn, _)] =
                      value.flatten(value)
                    expect val_hash == own_hash
                    list.concat(
                      acc,
                      [(val_tn, address.stake_credential, col, debt)],
                    )
                  }
                },
              )
            trace @"3. Get exchange rates"
            let t.Er2Red { u_num, u_denom, o_num, o_denom } =
              get_er(erp_hash, reference_inputs, redeemers)
            trace @"4. The first set of outputs are the continuing position in the same order as the inputs. "
            trace @"Thus we fold (or `map2`) over both: "
            let output_condensate =
              list.map2(
                input_condensate,
                outputs,
                fn(tup, o) {
                  let (val_tn, stake_cred, col, debt) = tup
                  expect Output {
                    address: cont_address,
                    datum: cont_datum,
                    value: cont_value,
                    reference_script: None,
                  } = o
                  trace @"    1. Address is as input"
                  expect
                    cont_address == Address {
                      payment_credential: own_cred,
                      stake_credential: stake_cred,
                    }
                  trace @"    2. Value is `cont_col` lovelace and validity token with tag `tag`"
                  expect [(_, _, cont_col), (cont_val_hash, cont_val_tn, _)] =
                    value.flatten(cont_value)
                  expect cont_val_hash == own_hash
                  expect cont_val_tn == val_tn
                  trace @"    3. Datum is `Position(cont_debt)`"
                  let cont_debt = get_debt(cont_datum)
                  trace @"    4. Calculate `delta_col = cont_col - col` and `delta_debt = cont_debt - debt`"
                  let delta_col = cont_col - col
                  let delta_debt = cont_debt - debt
                  trace @"    5. If `tag != only_tag`, then `cont_debt == 0` else `delta_debt < 0`"
                  expect
                    if cont_val_tn == only_val_tn {
                      and {
                        delta_debt <= 0,
                        cont_debt >= 0, 
                      }
                    } else {
                      cont_debt == 0
                    }
                  trace @"    6. Check `delta_col` is expected given exchange rate"
                  trace cbor.diagnostic([delta_col , u_denom, delta_debt , u_num])
                  expect delta_col * u_denom >= delta_debt * u_num
                  trace @"    7. Calculate fee tier and fee"
                  let f_num = redeem_fee_num(u_num, u_denom, col, debt)
                  let fee_usd_10000 = delta_debt * f_num
                  trace @"    8. Aggregate fee and debt as `total_fee` and `total_debt`"
                  (fee_usd_10000, delta_debt)
                },
              )
            let (fee_usd_10000, total_debt) =
              list.foldr(
                output_condensate,
                (0, 0),
                fn(curr, acc) { (curr.1st + acc.1st, curr.2nd + acc.2nd) },
              )
            let fee_obyiii =
              redeem_fee(o_num, o_denom, u_num, u_denom, fee_usd_10000)
            trace @"5. The next output is treasury output "
            expect Some(treas_output) =
              list.at(outputs, list.length(input_condensate))
            expect Output {
              address: treas_output,
              value: treas_val,
              datum: InlineDatum(treas_datum),
              reference_script: None,
            } = treas_output
            trace @"    1. Address is own"
            expect treas_output.payment_credential == own_cred
            trace @"    2. Value is ada + obyiii fee matching `total_fee`"
            expect [_, (treas_val_hash, treas_val_tn, treas_val_qty)] =
              value.flatten(treas_val)
            expect and {
                treas_val_hash == obyiii_hash,
                treas_val_tn == tokens.obyiii(),
                treas_val_qty >= fee_obyiii,
              }
            trace @"    3. Datum is `Treasury`"
            expect t.Treasury: t.MDat = treas_datum
            trace @"6. `- total_debt >= MIN_REDEEM_AMOUNT`"
            expect -total_debt >= c.min_redeem_amount()
            trace @"7. Own mint value is "
            trace @"    1. (obyusd, `- total_debt`)"
            expect [Pair(mint_tn, mint_qty)] = own_mint
            expect and {
                (mint_tn == tokens.obyusd())?,
                (mint_qty == total_debt)?,
              }
            True
          }
          t.Lqd(tag) -> {
            trace @"1. Redeemer is `Lqd(tag)`"
            trace @"2. Own inputs is `[own_input]` "
            expect [own_input] =
              list.filter(
                inputs,
                fn(i) { i.output.address.payment_credential == own_cred },
              )
            trace @"3. Extract `(own_col, own_debt)` from `own_input`"
            let (own_col, own_debt) = extract_position(own_input.output)
            trace @"4. Get exchange rates"
            let t.Er2Red { u_num, u_denom, .. } =
              get_er(erp_hash, reference_inputs, redeemers)
            trace @"5. `(own_col, own_debt)` is below MCR threshold"
            expect !above_mcr(u_num, u_denom, own_col, own_debt)
            trace @"6. Own mint value is"
            trace @"    1. (validity token `tag`, -1)"
            trace @"    2. (obyusd, `-own_debt`)"
            expect [Pair(an1, qty1), Pair(an2, qty2)] = own_mint
            expect and {
                an1 == tokens.user_validity_token(tag),
                qty1 == -1,
                an2 == tokens.obyusd(),
                qty2 == -own_debt,
              }
            True
          }
          t.Lwc(t.LwcParams { tag, treas_idx }) -> {
            trace @"1. Redeemer is `Lwc({tag, treas_idx})`"
            trace @"2. Own inputs is `own_inputs`"
            let own_inputs =
              list.filter(
                inputs,
                fn(i) { i.output.address.payment_credential == own_cred },
              )
            trace @"3. Only one position input, `own_position`, the rest are treasury inputs, `treasury_inputs`."
            expect [own_position] =
              list.filter(
                own_inputs,
                fn(i) {
                  expect InlineDatum(datum_inner) = i.output.datum
                  expect dat: t.MDat = datum_inner
                  when dat is {
                    t.Position(_) -> True
                    _ -> False
                  }
                },
              )
            trace @"4. Extract `(own_col, own_debt)` from `own_position`"
            let (own_col, own_debt) = extract_position(own_position.output)
            trace @"5. Extract (`total_comp`, `min_comp`), the total and min microobyiii respectively from `treasury_inputs`"
            let (total_comp, min_comp) =
              list.foldr(
                own_inputs,
                (0, c.total_obyiii() + 1),
                fn(cur: Input, acc: (Int, Int)) {
                  let Output { value, datum, .. } = cur.output
                  expect InlineDatum(datum_inner) = datum
                  expect dat: t.MDat = datum_inner
                  when dat is {
                    t.Treasury -> {
                      let q =
                        value.quantity_of(value, obyiii_hash, tokens.obyiii())
                      let tot = acc.1st + q
                      let min =
                        if q < acc.2nd {
                          q
                        } else {
                          acc.2nd
                        }
                      (tot, min)
                    }
                    t.Position(_) -> acc
                  }
                },
              )
            trace @"6. Get exchange rates"
            let t.Er2Red { u_num, u_denom, o_num, o_denom } =
              get_er(erp_hash, reference_inputs, redeemers)
            trace @"7. `(own_col, own_debt)` is below CCR threshold"
            expect !above_ccr(u_num, u_denom, own_col, own_debt)
            trace @"8. `comp` is calculated by : "
            let comp =
              if treas_idx >= 0 {
                trace @"    1. If `treas_idx >= 0`, then `treas_idx` output is treasury output"
                expect Some(treas_output) = list.at(outputs, treas_idx)
                expect Output {
                  address: treas_address,
                  value: treas_value,
                  datum: treas_datum,
                  reference_script : None
                } = treas_output
                trace @"        1. Own payment address"
                expect treas_address == Address(own_cred, None)
                trace @"        2. Value is ada + `obyiii_fee` microobyiii "
                expect [_, (treas_hash, treas_name, over_comp)] =
                  value.flatten(treas_value)
                expect and {
                    treas_hash == obyiii_hash,
                    treas_name == tokens.obyiii(),
                  }
                trace @"        3. Datum is `Treasury`"
                expect InlineDatum(treas_datum_inner) = treas_datum
                expect t.Treasury: t.MDat = treas_datum_inner
                trace @"        `comp = total_comp - over_comp`"
                total_comp - over_comp
              } else {
                trace @"    2. Else `comp = total_comp`"
                total_comp
              }
            trace @"9. All treasury inputs are necessary: `total_comp - min_comp < comp`."
            expect total_comp - min_comp < comp
            trace @"10. Verify `comp` is legitimate"
            expect
              verify_compensation(
                o_num,
                o_denom,
                u_num,
                u_denom,
                own_col,
                own_debt,
                comp,
              )
            trace @"10. Own mint value is"
            trace @"    1. (obyusd, `-own_debt`)"
            trace @"    2. (validity token `tag`, -1)"
            expect [Pair(an1, qty1), Pair(an2, qty2)] = own_mint
            expect and {
                an1 == tokens.user_validity_token(tag),
                qty1 == -1,
                an2 == tokens.obyusd(),
                qty2 == -own_debt,
              }
            True
          }
          t.Tidy -> {
            trace @"1. Redeemer is `Tidy`"
            trace @"2. `n_inputs` of own inputs:"
            trace @"    1. Value totals `input_ada` of lovelace and `input_obyiii` of microobyiii"
            trace @"    2. Datum is always `Treasury` "
            let (n_inputs, input_ada, input_obyiii) =
              list.foldr(
                inputs,
                (0, 0, 0),
                fn(cur: Input, acc: (Int, Int, Int)) {
                  let Output { address, value, datum, .. } = cur.output
                  if address.payment_credential == own_cred {
                    expect InlineDatum(datum_inner) = datum
                    expect dat: t.MDat = datum_inner
                    when dat is {
                      t.Treasury -> {
                        let ada = value |> value.lovelace_of 
                        let obyiii = value |> value.quantity_of(
                          obyiii_hash,
                          tokens.obyiii(),
                        )

                        (acc.1st + 1, acc.2nd + ada, acc.3rd + obyiii)
                      }
                      _ -> fail @"Treasury inputs only"
                    }
                  } else {
                    acc
                  }
                },
              )
            trace @"3. First `n_outputs` are treasury outputs:"
            expect [treas_output, ..rest] = outputs
            expect Output {
              address : treas_address,
              value : treas_value,
              datum : InlineDatum(treas_datum), 
              reference_script: None, 
            } = treas_output
            trace @"    1. Address is (unstaked) own address"
            expect treas_address == Address(own_cred, None)
            trace @"    2. Value is `output_ada` of lovelace and `output_obyiii` of microobyiii"
            expect [(_,_,output_ada), (treas_pid, treas_tn, output_obyiii)] = treas_value |> value.flatten()
            expect and {
              treas_pid == obyiii_hash, 
              treas_tn == tokens.obyiii(),
            }
            trace @"    3. Datum is `Treasury`"
            expect t.Treasury: t.MDat = treas_datum 
            let n_outputs = 1 + (rest |> count_while(fn(o) { o == treas_output }))
            trace @"4. Number of own outputs no greater than own inputs ie `n_inputs >= n_outputs`"
            trace @"5. Output ada at least as great as input ie `input_ada <= output_ada * n_outputs`"
            trace @"6. Output microobyiii is (almost) as great as input. (Grace allows for rounding down)"
            expect and {
              (n_inputs >= n_outputs)?,
              (input_ada <= n_outputs * output_ada)?,
              (input_obyiii - n_outputs < n_outputs * output_obyiii)?,
            }
            trace @"7. Get exchange rates"
            let t.Er2Red { o_num, o_denom, u_num, u_denom, } =
              get_er(erp_hash, reference_inputs, redeemers)
            trace @"8. Calculate `max_treasury_obyiii` from the dollar limit `MAX_TREASURY_UTXO`"
            trace @"9. `max_output <= max_treasury_obyiii`"
            expect
              output_obyiii <= max_treasury_utxo_microobyiii(
                o_num,
                o_denom,
                u_num,
                u_denom,
              )
            trace @"10. Own mint value is []"
            expect [] = own_mint
            trace @"11. Reference inputs includes a position below CCR"
            expect Some((col, debt)) = extract_position_with_checks(own_cred, own_hash, reference_inputs)
            !above_ccr(u_num, u_denom, col, debt)
          }
          t.Burn -> {
            trace @"1. Redeemer is `Burn`"
            trace @"2. Own inputs are []"
            expect [] =
              list.filter(
                inputs,
                fn(i) { i.output.address.payment_credential == own_cred },
              )
            trace @"3. Own mint quantities are < 0"
            expect
              list.all(own_mint, fn(tup: Pair<ByteArray, Int>) { tup.2nd < 0 })
            True
          }
        }
      }
      _ -> False
    }
  }

  fn m3(_dat: t.MDat, _red: Data, ctx: ScriptContext) {
    let ScriptContext { transaction, purpose } = ctx
    expect Spend(own_oref) = purpose
    trace @"1. Withdraws includes own credential "
    let Transaction { inputs, withdrawals, .. } = transaction
    let own_cred = get_payment_cred(own_oref, inputs)
    expect Some(_) = pairs.get_first(withdrawals, Inline(own_cred))
    True
  }
}

fn get_er(
  erp_hash: ByteArray,
  ref_inputs: List<Input>,
  redeemers: Pairs<ScriptPurpose, Redeemer>,
) -> t.Er2Red {
  let pointers =
    list.filter(
      ref_inputs,
      fn(i) {
        value.quantity_of(i.output.value, erp_hash, tokens.erp_validity_token()) == 1
      },
    )
  when pointers is {
    [pointer] -> {
      expect InlineDatum(d) = pointer.output.datum
      expect parsed_d: t.ErpDat = d
      when pairs.get_first(redeemers, WithdrawFrom(Inline(parsed_d))) is {
        Some(l) -> {
          expect d: t.Er2Red = l
          d
        }
        _ -> fail @"Wrong xrate"
      }
    }
    _ -> fail @"No xrate"
  }
}

fn above_cr(
  m_num: Int,
  m_denom: Int,
  u_num: Int,
  u_denom: Int,
  col: Int,
  debt: Int,
) {
  m_denom * u_denom * col - m_num * u_num * debt >= 0
}

fn above_mcr(u_num, u_denom, col, debt) {
  let (m_num, m_denom) = c.minimal_collateral_ratio()
  above_cr(m_num, m_denom, u_num, u_denom, col, debt)
}

fn above_ccr(u_num: Int, u_denom: Int, col: Int, debt: Int) {
  let (m_num, m_denom) = c.critical_collateral_ratio()
  above_cr(m_num, m_denom, u_num, u_denom, col, debt)
}

fn sufficient_fee(o_num: Int, o_denom: Int, u_num: Int, u_denom: Int, debt: Int, fee: Int) {
  let (fr_num, fr_denom) = c.fee_rate()
  fr_denom * o_num * u_denom * fee - fr_num * o_denom * u_num * debt >= 0
}

fn sufficient_fee_test_vecs() {
  // Tests written for fr = (2, 100) or (1,100)
  let (fr_num, fr_denom) = c.fee_rate()
  let f = fr_num 
  let d = fr_denom
  [
    (1,1,1,1,d,f,True),
    (1,1,1,1,d-1,f,True),
    (1,1,1,1,d+1,f,False),
    (2,1,1,1,d,f,True),
    (2,1,1,1,d-1,f,True),
    (2,1,1,1,d+1,f,True),
    (1,2,1,1,d,2*f,True),
    (1,2,1,1,d-1,2*f,True),
    (1,2,1,1,d+1,2*f,False),
    (1,1,2,1,d,2*f,True),
    (1,1,2,1,d-1,2*f,True),
    (1,1,2,1,d+1,2*f,False),
    (1,1,1,2,2*d,f,True),
    (1,1,1,2,2*d-1,f,True),
    (1,1,1,2,2*d+1,f,False),
    (1,1,1,1,2*d,2*f,True),
    (1,1,1,1,d-1,2*f,True),
    (1,1,1,1,2*d + 1,2*f,False),
    (2,1,2,1,d,f,True),
    (2,1,2,1,d-1,f,True),
    (2,1,2,1,d+1,f,False),
  ]
}

test test_sufficient_fee() {
  let vecs = sufficient_fee_test_vecs()
  vecs |> list.all(fn (vec) {
    sufficient_fee(vec.1st, vec.2nd, vec.3rd, vec.4th, vec.5th, vec.6th) == vec.7th
  })
}


fn verify_compensation(
  o_num: Int,
  o_denom: Int,
  u_num: Int,
  u_denom: Int,
  col: Int,
  debt: Int,
  compensation: Int,
) {
  let (t_num, t_denom) = c.treasury_top_up()
  t_denom * u_denom * ( o_num * compensation + o_denom * col ) <= t_num * o_denom * u_num * debt
}

fn max_treasury_utxo_microobyiii(
  o_num: Int,
  o_denom: Int,
  u_num: Int,
  u_denom: Int,
) {
  c.max_treasury_utxo() * o_denom * u_num / ( o_num * u_denom )
}

fn redeem_fee_num(u_num: Int, u_denom: Int, col: Int, debt: Int) -> Int {
  let f_num_lin = ( 400 * u_denom * col + 1100 * u_num * debt ) / (17 * u_num * debt )
  math.min(300, math.max(f_num_lin, 100))
}

fn redeem_fee_denom() {
  10000
}

fn redeem_fee_num_test_vecs() {
  [
    (1, 1, 100, 100, 100),
    (1, 1, 300, 300, 100),
    (1, 1, 120, 100, 100),
    (1, 1, 150, 100, 100),
    (1, 1, 575, 100, 200),
    (1,1,999,100,299),
    (1,1,1000,100,300),
    (1, 2, 100, 100, 111),
    (2, 1, 400, 100, 111),
  ]
}

test test_redeem_fee_num() {
  let vecs = redeem_fee_num_test_vecs()
  vecs |> list.all(fn (vec) {
    redeem_fee_num(vec.1st, vec.2nd, vec.3rd, vec.4th, ) == vec.5th
  })
}


fn redeem_fee(
  o_num: Int,
  o_denom: Int,
  u_num: Int,
  u_denom: Int,
  fee_usd_10000: Int,
) -> Int {
  fee_usd_10000 * o_denom * u_num / ( o_num * u_denom * redeem_fee_denom() )
}

fn get_payment_cred(oref: OutputReference, inputs: List<Input>) -> Credential {
  when inputs is {
    [input, ..rest] -> {
      let Input { output_reference, output } = input
      if output_reference == oref {
        output.address.payment_credential
      } else {
        get_payment_cred(oref, rest)
      }
    }
    [] -> fail @"No more inputs"
  }
}

fn extract_position(pos: Output) -> (Int, Int) {
  let Output { value, datum, .. } = pos
  expect [(_, _, col), _] = value.flatten(value)
  expect InlineDatum(datum_inner) = datum
  expect t.Position(debt): t.MDat = datum_inner
  (col, debt)
}

fn extract_position_with_checks(own_cred: Credential, own_hash: ByteArray, poss: List<Input>) -> Option<(Int, Int)> {
  when poss is {
    [] -> None
    [pos, ..rest] -> {
      let Output { address, value, datum, .. } = pos.output
      if address.payment_credential == own_cred {
          expect [(_, _, col), (pid, tn, _)] = value.flatten(value)
          expect pid == own_hash
          expect (tn |> bytearray.take(tokens.user_pref_len())) == (tokens.user_auth_pref())
          expect InlineDatum(datum_inner) = datum
          expect t.Position(debt): t.MDat = datum_inner
          Some((col, debt))
      } else {
        extract_position_with_checks(own_cred, own_hash, rest)
      }
    }
  }
}

fn tot_min(q: Int, acc: (Int, Int)) {
  let tot = acc.1st + q
  let min =
    if q < acc.2nd {
      q
    } else {
      acc.2nd
    }
  (tot, min)
}

fn get_debt(datum: Datum) -> Int {
  expect InlineDatum(dat) = datum
  expect t.Position(debt): t.MDat = dat
  debt
}

test test_tot_min() {
  list.foldr([1, 2, 3, 4, 5], (0, 0), tot_min) == (15, 0)
}

fn count_while(l : List<t>, pred : fn(t) -> Bool ) -> Int {
  when l is {
    [] -> 0
    [n, ..rest] -> {
      when pred(n) is {
        True -> 1 + count_while(rest, pred)
        False -> 0
      }
    }
  }
}


