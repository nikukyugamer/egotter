# == Schema Information
#
# Table name: search_histories
#
#  id         :integer          not null, primary key
#  session_id :string(191)      default(""), not null
#  user_id    :integer          not null
#  uid        :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_search_histories_on_created_at  (created_at)
#  index_search_histories_on_session_id  (session_id)
#  index_search_histories_on_user_id     (user_id)
#

class SearchHistory < ActiveRecord::Base
  belongs_to :user
  has_one :twitter_db_user, primary_key: :uid, foreign_key: :uid, class_name: 'TwitterDB::User'

  validates :user_id, numericality: {only_integer: true}
  validates :session_id, format: {with: /\A.+\w+.+\Z/}

  def self.latest(session_id: nil, user_id: nil)
    condition = user_id ? {user_id: user_id} : {session_id: session_id}
    includes(:twitter_db_user).where(condition).order(created_at: :desc).limit(10)
  end

  delegate :screen_name, :name, :description, :profile_image_url_https, :protected, :verified, :suspended, :inactive, :status, to: :twitter_db_user, allow_nil: true
end
