# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  uid                    :string(191)      not null
#  secret                 :string(191)      not null
#  token                  :string(191)      not null
#  notification           :boolean          default(TRUE), not null
#  email                  :string(191)      not null
#  encrypted_password     :string(191)      not null
#  reset_password_token   :string(191)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(191)
#  last_sign_in_ip        :string(191)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_uid                   (uid) UNIQUE
#

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable

  def self.find_or_create_for_oauth_by!(auth)
    user = User.find_by(uid: auth.uid)
    unless user
      user = User.create!(
        uid: auth.uid,
        secret: auth.credentials.secret,
        token: auth.credentials.token,
        email: "#{auth.provider}-#{auth.uid}@example.com",
        password: Devise.friendly_token[4, 30])
    end
    user
  end
end
