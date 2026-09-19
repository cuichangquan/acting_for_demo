class Purchase < ApplicationRecord
  belongs_to :user
  belongs_to :product
  validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
