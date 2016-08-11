require 'active_support/concern'

module Concerns::TwitterUser::Utils
  extend ActiveSupport::Concern

  class_methods do
    def has_more_than_two_records?(uid, user_id)
      where(uid: uid, user_id: user_id).limit(2).pluck(:id).size >= 2
    end

    def oldest(user, user_id)
      user.kind_of?(Integer) ?
        order(created_at: :asc).find_by(uid: user.to_i, user_id: user_id) : order(created_at: :asc).find_by(screen_name: user.to_s, user_id: user_id)
    end

    def latest(user, user_id)
      user.kind_of?(Integer) ?
        order(created_at: :desc).find_by(uid: user.to_i, user_id: user_id) : order(created_at: :desc).find_by(screen_name: user.to_s, user_id: user_id)
    end
  end

  DEFAULT_SECONDS = Rails.configuration.x.constants['twitter_user_recently_created']

  included do
  end

  def mention_name
    "@#{screen_name}"
  end

  def friend_uids
    new_record? ? friends.map { |f| f.uid.to_i } : friends.pluck(:uid).map { |uid| uid.to_i }
  end

  def follower_uids
    new_record? ? followers.map { |f| f.uid.to_i } : followers.pluck(:uid).map { |uid| uid.to_i }
  end

  def recently_created?(seconds = DEFAULT_SECONDS)
    Time.zone.now.to_i - created_at.to_i < seconds
  end

  def recently_updated?(seconds = DEFAULT_SECONDS)
    Time.zone.now.to_i - updated_at.to_i < seconds
  end

  def latest
    TwitterUser.latest(uid.to_i, user_id)
  end

  def search_and_touch
    update!(search_count: search_count + 1)
  rescue => e
    logger.error "#{self.class}##{__method__}: #{e.class} #{e.message}"
  end

  def update_and_touch
    update!(update_count: update_count + 1)
  rescue => e
    logger.error "#{self.class}##{__method__}: #{e.class} #{e.message}"
  end
end