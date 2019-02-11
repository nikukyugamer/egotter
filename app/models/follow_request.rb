# == Schema Information
#
# Table name: follow_requests
#
#  id            :integer          not null, primary key
#  user_id       :integer          not null
#  uid           :bigint(8)        not null
#  finished_at   :datetime
#  error_class   :string(191)      default(""), not null
#  error_message :string(191)      default(""), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_follow_requests_on_created_at  (created_at)
#  index_follow_requests_on_user_id     (user_id)
#

class FollowRequest < ApplicationRecord
  include Concerns::Request::FollowAndUnfollow

  belongs_to :user
  validates :user_id, numericality: :only_integer
  validates :uid, numericality: :only_integer

  def ready?
    Concerns::User::FollowAndUnfollow::Util.global_can_create_follow? && user.can_create_follow?
  end

  def perform!(client = nil)
    client = user.api_client.twitter unless client

    raise Concerns::FollowAndUnfollowWorker::CanNotFollowYourself if user.uid == uid
    raise Concerns::FollowAndUnfollowWorker::NotFound unless client.user?(uid)
    raise Concerns::FollowAndUnfollowWorker::HaveAlreadyFollowed if client.friendship?(user.uid, uid)
    raise Concerns::FollowAndUnfollowWorker::HaveAlreadyRequestedToFollow if friendship_outgoing?(client, uid)

    client.follow!(uid)
    finished!
  end

  def perform(client = nil)
    perform!(client)
  rescue Twitter::Error::Unauthorized => e
    if e.message == 'Invalid or expired token.'
      update(error_class: e.class, error_message: e.message)
    else
      raise
    end
  rescue Twitter::Error::Forbidden => e
    if e.message == 'User has been suspended.'
      update(error_class: e.class, error_message: e.message)
    else
      raise
    end
  rescue Concerns::FollowAndUnfollowWorker::CanNotFollowYourself,
      Concerns::FollowAndUnfollowWorker::NotFound,
      Concerns::FollowAndUnfollowWorker::HaveAlreadyFollowed,
      Concerns::FollowAndUnfollowWorker::HaveAlreadyRequestedToFollow => e
    update(error_class: e.class, error_message: e.message.truncate(150))
  end

  def friendship_outgoing?(client, uid)
    client.friendships_outgoing.attrs[:ids].include?(uid)
  rescue => e
    logger.warn "#{__method__} #{e.class} #{e.message}"
    false
  end

  def enqueue(enqueue_location: nil)
    if collect_follow_or_unfollow_sidekiq_jobs(self.class.to_s, user_id).empty?
      CreateFollowWorker.perform_in(current_interval, user_id, enqueue_location: enqueue_location)
    end
  end

  def current_interval
    Concerns::User::FollowAndUnfollow::Util.global_can_create_follow? ? 10.seconds : Concerns::User::FollowAndUnfollow::Util.limit_interval
  end
end
