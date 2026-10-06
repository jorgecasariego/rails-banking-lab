# Sample accounts used in the README examples and script/adversarial_experiments.rb.
#
# Safe to run repeatedly: accounts are looked up by owner_name, and an
# existing account is left untouched. The balances are only used when an
# account is created for the first time. No transactions are created.
return if Rails.env.production?

{
  "Jorge" => 6_000,
  "Alice" => 9_000,
  "Bob" => 5_000
}.each do |owner_name, balance_cents|
  Account.find_or_create_by!(owner_name: owner_name) do |account|
    account.balance_cents = balance_cents
  end
end
