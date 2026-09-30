class Account < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_error

  validates :owner_name, presence: true
end
