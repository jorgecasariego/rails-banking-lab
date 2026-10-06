class TransfersController < ApplicationController
  def new
    @accounts = Account.all
  end

  def create
    sender = Account.find(transfer_params[:sender_id])
    recipient = Account.find(transfer_params[:recipient_id])
    amount_cents = transfer_params[:amount_cents].to_i

    MoneyTransfer.new(
      sender: sender,
      recipient: recipient,
      amount_cents: amount_cents
    ).call

    redirect_to account_transactions_path(sender)
  rescue MoneyTransfer::Error => e
    @accounts = Account.all
    @error = e.message

    render :new, status: :unprocessable_entity
  end

  private

  def transfer_params
    params.expect(transfer: [ :sender_id, :recipient_id, :amount_cents ])
  end
end
