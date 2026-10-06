class ToolCallHandler
  Result = Data.define(:status, :data, :error) do
    def self.confirmation_required(data) = new(status: :confirmation_required, data: data, error: nil)
    def self.rejected(error) = new(status: :rejected, data: nil, error: error)
  end

  InvalidArguments = Class.new(StandardError)

  TRANSFER_MONEY_KEYS = %w[recipient_id amount_cents].freeze

  def initialize(current_account:)
    @current_account = current_account
  end

  def call(tool_call)
    case ToolPolicy.decision_for(tool_call.name)
    when :confirm
      propose_transfer_money(tool_call.arguments)
    else
      Result.rejected("tool not allowed: #{tool_call.name.inspect}")
    end
  end

  private

  # Validates the proposal and stops at the confirmation boundary.
  # Nothing here may change balances; a person must confirm first.
  def propose_transfer_money(arguments)
    Result.confirmation_required(parse_transfer_money(arguments))
  rescue InvalidArguments => e
    Result.rejected(e.message)
  end

  # Arguments arrive as parsed JSON, so keys are strings. The sender is
  # always current_account, so sender_id/account_id are unexpected keys.
  def parse_transfer_money(arguments)
    raise InvalidArguments, "arguments must be an object" unless arguments.is_a?(Hash)

    unexpected = arguments.keys - TRANSFER_MONEY_KEYS
    raise InvalidArguments, "unexpected arguments: #{unexpected.join(", ")}" if unexpected.any?

    recipient_id = strict_integer(arguments["recipient_id"], "recipient_id")
    amount_cents = strict_integer(arguments["amount_cents"], "amount_cents")
    raise InvalidArguments, "amount_cents must be positive" unless amount_cents.positive?

    recipient = Account.find_by(id: recipient_id)
    raise InvalidArguments, "recipient not found" if recipient.nil?
    raise InvalidArguments, "cannot transfer to the same account" if recipient == @current_account

    {
      sender_id: @current_account.id,
      recipient_id: recipient.id,
      recipient_name: recipient.owner_name,
      amount_cents: amount_cents
    }
  end

  # Accepts a JSON integer or a string of ASCII digits. Unlike to_i, it
  # never turns junk like "abc", "25.00" or nil into a number.
  def strict_integer(value, name)
    case value
    when Integer
      value
    when String
      raise InvalidArguments, "#{name} must be an integer" unless value.match?(/\A\d+\z/)
      Integer(value, 10)
    else
      raise InvalidArguments, "#{name} must be an integer"
    end
  end
end
