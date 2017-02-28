# == Schema Information
#
# Table name: inactive_friendships
#
#  id         :integer          not null, primary key
#  from_uid   :integer          not null
#  friend_uid :integer          not null
#  sequence   :integer          not null
#
# Indexes
#
#  index_inactive_friendships_on_friend_uid  (friend_uid)
#  index_inactive_friendships_on_from_uid    (from_uid)
#

class InactiveFriendship < ActiveRecord::Base
  belongs_to :twitter_user, primary_key: :uid, foreign_key: :from_uid
  belongs_to :inactive_friend, primary_key: :uid, foreign_key: :friend_uid, class_name: 'TwitterDB::User'

  def self.import_from!(from_uid, friend_uids)
    friendships = friend_uids.map.with_index { |friend_uid, i| [from_uid.to_i, friend_uid.to_i, i] }

    ActiveRecord::Base.transaction do
      delete_all(from_uid: from_uid)
      import(%i(from_uid friend_uid sequence), friendships, validate: false, timestamps: false)
    end
  end
end