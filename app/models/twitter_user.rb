# == Schema Information
#
# Table name: twitter_users
#
#  id          :integer          not null, primary key
#  uid         :string           not null
#  screen_name :string           not null
#  user_info   :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_twitter_users_on_screen_name  (screen_name)
#  index_twitter_users_on_uid          (uid)
#

class TwitterUser < ActiveRecord::Base
  has_many :friends, foreign_key: :from_id, dependent: :destroy
  has_many :followers, foreign_key: :from_id, dependent: :destroy

  SAVE_KEYS = %i(
    id
    name
    screen_name
    location
    description
    url
    protected
    followers_count
    friends_count
    listed_count
    favourites_count
    utc_offset
    time_zone
    geo_enabled
    verified
    statuses_count
    lang
    profile_image_url_https
    profile_banner_url
    suspended
  )

  delegate *SAVE_KEYS.reject { |k| k.in?(%i(id screen_name)) }, to: :user_info_hash

  def user_info_hash
    @user_info_hash ||= Hashie::Mash.new(JSON.parse(user_info))
  end

  def self.create_me_with_friends_and_followers(client, uid)
    # call 2 times to use cache
    me = client.user(uid.to_i) && client.user(uid.to_i)
    friends, followers = client.friends_and_followers(me.id.to_i) && client.friends_and_followers(me.id.to_i)
    tw_user = nil

    self.transaction do
      tw_user = self.create_by_raw_user(me)
      tw_user.save_raw_friends(friends)
      tw_user.save_raw_followers(followers)
    end

    tw_user
  end

  def self.create_by_raw_user(data)
    if data.kind_of?(Hash) # TODO check keys and values
      create({
               uid: data.id,
               screen_name: data.screen_name,
               user_info: data.slice(*SAVE_KEYS).to_json})
    else
      raise
    end
  end

  def save_raw_friends(data)
    if data.kind_of?(Array) && data.first.kind_of?(Hash)
      data.each_slice(100).each do |_data|
        __data = _data.map do |d|
          Friend.new({
                       from_id: id,
                       uid: d.id,
                       screen_name: d.screen_name,
                       user_info: d.slice(*SAVE_KEYS).to_json})
        end
        Friend.import(__data)
      end
    else
      raise
    end
  end

  def save_raw_followers(data)
    if data.kind_of?(Array) && (data.first.kind_of?(Twitter::User) || data.first.kind_of?(Hash))
      data.each_slice(100).each do |_data|
        __data = _data.map do |d|
          Follower.new({
                         from_id: id,
                         uid: d.id,
                         screen_name: d.screen_name,
                         user_info: d.slice(*SAVE_KEYS).to_json})
        end
        Follower.import(__data)
      end
    else
      raise
    end
  end

  scope :oldest, -> (uid){ order(created_at: :asc).find_by(uid: uid) }
  scope :latest, -> (uid){ order(created_at: :desc).find_by(uid: uid) }

  def recently_created?
    Time.now.to_i - created_at.to_i < 1800 # 30 minutes
  end

  def oldest_me
    TwitterUser.oldest(uid)
  end

  def latest_me
    TwitterUser.latest(uid)
  end

  def mutual_friends
    ExTwitter.new.mutual_friends(self)
  end

  def removed_friends
    return [] if TwitterUser.where(screen_name: screen_name).limit(2).size < 2
    ExTwitter.new.removed_friends(oldest_me, latest_me)
  end

  def removed_followers
    return [] if TwitterUser.where(screen_name: screen_name).limit(2).size < 2
    ExTwitter.new.removed_followers(oldest_me, latest_me)
  end
end
