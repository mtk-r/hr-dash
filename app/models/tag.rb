# == Schema Information
#
# Table name: tags
#
#  id         :integer          not null, primary key
#  status     :integer          default(0), not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Tag < ActiveRecord::Base
  VALID_NAME_REGEX = /\A(?:[a-zA-Z0-9_\.\+\#\'-]|\p{Blank}|\p{Hiragana}|\p{Katakana}|[ー－]|[一-龠々])+\z/

  validates :status, presence: true
  validates :name, length: { maximum: 32 }, presence: true, format: { with: VALID_NAME_REGEX }

  enum status: { unfixed: 0, fixed: 1 }
end
