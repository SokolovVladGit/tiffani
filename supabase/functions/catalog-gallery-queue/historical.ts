/**
 * Observations from earlier dry-runs. Applied once, only when a product
 * has no queue row yet. They set next_check_at; they are not a blacklist.
 */
export const HISTORICAL_NO_EXTRA = [
  "100306356882",
  "101435230961",
  "101934869712",
  "102754057802",
  "103804395752",
  "107888673654",
  "108100596374",
  "109888941192",
  "111139632692",
  "111758762772",
  "114304977694",
  "114670519104",
  "114675859692",
  "114711145602",
  "115322432522",
  "116492260294",
  "118231263891",
  "118946524362",
  "119722333401",
  "119995685974",
  "120098099242",
  "120186887004",
] as const;

export const HISTORICAL_AMBIGUOUS = ["111053550692"] as const;

export const HISTORICAL_AMBIGUOUS_DETAIL =
  "historical_observation: page editions 2, database variants 1";
