class TransactionsController < ApplicationController
  def index
    @account = Account.find(params[:account_id])
    @transactions = @account.transactions
  end

  def new
    @account = Account.find(params[:account_id])
    @transaction = @account.transactions.build
  end

  def create
    @account = Account.find(params[:account_id])
    @transaction = @account.transactions.build(transaction_params)

    if @transaction.save
      redirect_to account_transactions_path(@account)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def transaction_params
    params.expect(transaction: [ :description, :amount_cents ])
  end
end
