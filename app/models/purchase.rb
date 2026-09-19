class Purchase < ApplicationRecord
  SOURCES = %w[human shopping_agent].freeze

  belongs_to :user
  belongs_to :product
  validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :source, inclusion: { in: SOURCES }
end
