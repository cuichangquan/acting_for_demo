class User < ApplicationRecord
  has_many :purchases, dependent: :restrict_with_error
  validates :name, presence: true
end
