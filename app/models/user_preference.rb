# == Schema Information
#
# Table name: user_preferences
#
#  user_id :bigint           not null, primary key
#  k       :string           not null, primary key
#  v       :string           not null
#
# Foreign Keys
#
#  user_preferences_user_id_fkey  (user_id => users.id)
#

class UserPreference < ApplicationRecord
  belongs_to :user

  validates :user, :associated => true
  validates :k, :v, :length => 1..255, :characters => true
end
