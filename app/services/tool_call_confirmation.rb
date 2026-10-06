# The only path from a tool call to MoneyTransfer. Application code calls
# this after a person confirms a proposal; it is never handed to the model.
class ToolCallConfirmation
  Result = ToolCallHandler::Result

  def initialize(current_account:)
    @current_account = current_account
  end

  def call(tool_call)
    unless ToolPolicy.decision_for(tool_call.name) == :confirm
      return Result.rejected("tool does not accept confirmation: #{tool_call.name.inspect}")
    end

    # Validate again against current database state, as if newly proposed.
    proposal = ToolCallHandler.new(current_account: @current_account).call(tool_call)
    return proposal unless proposal.status == :confirmation_required

    transfer_money(proposal.data)
  end

  private

  # MoneyTransfer locks and reloads both accounts, so the balance check
  # uses fresh data even if current_account was loaded earlier.
  def transfer_money(data)
    MoneyTransfer.new(
      sender: @current_account,
      recipient: Account.find(data[:recipient_id]),
      amount_cents: data[:amount_cents]
    ).call

    Result.new(status: :executed, data: data, error: nil)
  rescue MoneyTransfer::Error => e
    Result.rejected(e.message)
  end
end
