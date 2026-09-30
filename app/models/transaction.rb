class Transaction < ApplicationRecord
  belongs_to :account

  validates :description, presence: true
  validates :amount_cents,
            presence: true,
            numericality: { other_than: 0 }
end
