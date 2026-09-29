class Account < ApplicationRecord
  validates :owner_name, presence: true
end
