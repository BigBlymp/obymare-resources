pub type Rational =
  (Int, Int)

pub fn short_time() -> Int {
  30 * 60 * 1000
}

pub fn million() -> Int {
  1_000_000
}

pub fn total_obyiii() {
  10 * million() * million()
}

pub fn fee_rate() -> Rational {
  (1, 100)
}

pub fn minimal_collateral_ratio() -> Rational {
  (120, 100)
}

pub fn critical_collateral_ratio() -> Rational {
  (102, 100)
}

pub fn treasury_top_up() -> Rational {
  (105, 100)
}

pub fn max_debt_amount() -> Int {
  5 * million() * million()
}

pub fn min_debt_amount() -> Int {
  500 * million()
}

pub fn min_redeem_amount() -> Int {
  1_000 * million()
}

pub fn max_treasury_utxo() -> Int {
  10_000 * million()
}
