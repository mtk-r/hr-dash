# frozen_string_literal: true

# == Schema Information
#
# Table name: group_assignments
#
#  id         :integer          not null, primary key
#  group_id   :integer          not null
#  user_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

FactoryGirl.define do
  factory :group_assignment do
    association :group
    association :user
  end
end
