use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/transaction.{Input, Output, OutputReference}
use aiken/transaction/credential.{ScriptCredential}
use obymare/constants as c

pub fn short_validity_range_lb(validity_range: Interval<Int>) -> Int {
  expect Interval {
    lower_bound: IntervalBound { bound_type: Finite(lb), .. },
    upper_bound: IntervalBound { bound_type: Finite(ub), .. },
  } = validity_range
  expect ub - lb <= c.short_time()
  lb
}

pub fn get_script_hash(oref: OutputReference, inputs: List<Input>) -> ByteArray {
  when inputs is {
    [input, ..rest] -> {
      let Input { output_reference, output } = input
      if output_reference == oref {
        expect ScriptCredential(hash) = output.address.payment_credential
        hash
      } else {
        get_script_hash(oref, rest)
      }
    }
    [] -> fail @"No more inputs"
  }
}
