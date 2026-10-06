class MoneyTransfer
  class Error < StandardError; end
  class InvalidAmount < Error; end
  class InsufficientFunds < Error; end
  class SameAccount < Error; end

  def initialize(sender:, recipient:, amount_cents:)
    @sender = sender
    @recipient = recipient
    @amount_cents = amount_cents
  end

  def call
    raise InvalidAmount, "amount must be a positive integer" unless @amount_cents.is_a?(Integer) && @amount_cents.positive?
    raise SameAccount, "cannot transfer to the same account" if @sender == @recipient

    ActiveRecord::Base.transaction do
      # Lock in a consistent order so opposite transfers cannot deadlock.
      # lock! also reloads, so the balance check below uses fresh data.
      [ @sender, @recipient ].sort_by(&:id).each(&:lock!)

      raise InsufficientFunds, "insufficient balance" if @sender.balance_cents < @amount_cents

      @sender.update!(balance_cents: @sender.balance_cents - @amount_cents)
      @recipient.update!(balance_cents: @recipient.balance_cents + @amount_cents)

      @sender.transactions.create!(description: "Transfer to #{@recipient.owner_name}", amount_cents: -@amount_cents)
      @recipient.transactions.create!(description: "Transfer from #{@sender.owner_name}", amount_cents: @amount_cents)
    end
  end
end
