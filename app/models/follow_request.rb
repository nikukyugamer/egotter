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
  include Concerns::FollowRequest::Runnable

  has_many :logs, primary_key: :id, foreign_key: :request_id, class_name: 'CreateFollowLog'

  belongs_to :user
  validates :user_id, numericality: :only_integer
  validates :uid, numericality: :only_integer

  def perform!
    raise TooManyRetries if logs.size >= 5
    raise AlreadyFinished if finished?
    raise Unauthorized if unauthorized?
    raise CanNotFollowYourself if user.uid == uid
    raise NotFound unless user_found?
    raise AlreadyRequestedToFollow if friendship_outgoing?
    raise AlreadyFollowing if friendship?

    begin
      client.follow!(uid)
    rescue Twitter::Error::Unauthorized => e
      raise Unauthorized.new(e.message)
    rescue Twitter::Error::Forbidden => e
      if e.message.start_with?('To protect our users from spam and other malicious activity, this account is temporarily locked.')
        raise TemporarilyLocked
      elsif e.message.start_with?('Your account is suspended and is not permitted to access this feature.')
        raise Suspended
      elsif e.message.start_with?('You are unable to follow more people at this time.')
        raise TooManyFollows
      else
        raise Forbidden.new(e.message)
      end
    end
  end

  def unauthorized?
    !user.authorized? || !client.verify_credentials
  rescue Twitter::Error::Unauthorized => e
    if e.message == 'Invalid or expired token.'
      true
    else
      raise
    end
  end

  def user_found?
    client.user?(uid)
  rescue => e
    if e.message.start_with?('To protect our users from spam and other malicious activity, this account is temporarily locked.')
      raise TemporarilyLocked
    elsif AccountStatus.suspended?(e)
      raise Suspended
    else
      raise
    end
  end

  # Returns a collection of numeric IDs for every protected user for whom the authenticating user has a pending follow request.
  # TODO Cache this value.
  def friendship_outgoing?
    client.friendships_outgoing.attrs[:ids].include?(uid)
  rescue => e
    logger.warn "#{__method__} #{e.class} #{e.message} #{self.inspect}"
    false
  end

  def friendship?
    client.friendship?(user.uid, uid)
  end

  def client
    @client ||= user.api_client.twitter
  end

  class Error < StandardError
  end

  class DeadErrorTellsNoTales < Error
    def initialize(*args)
      super('')
    end
  end

  class TooManyRetries < DeadErrorTellsNoTales
  end

  class AlreadyFinished < DeadErrorTellsNoTales
  end

  class Unauthorized < Error
  end

  class Forbidden < Error
  end

  class Suspended < DeadErrorTellsNoTales
  end

  class TemporarilyLocked < DeadErrorTellsNoTales
  end

  class GlobalRateLimited < DeadErrorTellsNoTales
  end

  class UserRateLimited < DeadErrorTellsNoTales
  end

  class TooManyFollows < DeadErrorTellsNoTales
  end

  class CanNotFollowYourself < DeadErrorTellsNoTales
  end

  class NotFound < DeadErrorTellsNoTales
  end

  class AlreadyFollowing < DeadErrorTellsNoTales
  end

  class AlreadyRequestedToFollow < DeadErrorTellsNoTales
  end
end
