# == Schema Information
#
# Table name: create_prompt_report_requests
#
#  id          :bigint(8)        not null, primary key
#  user_id     :integer          not null
#  finished_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_create_prompt_report_requests_on_created_at  (created_at)
#  index_create_prompt_report_requests_on_user_id     (user_id)
#

class CreatePromptReportRequest < ApplicationRecord
  include Concerns::Request::Runnable
  belongs_to :user
  has_many :logs, -> { order(created_at: :asc) }, foreign_key: :request_id, class_name: 'CreatePromptReportLog'

  validates :user_id, presence: true

  def perform!
    validate!

    persisted_twitter_user = TwitterUser.latest_by(uid: user.uid)
    raise TooManyFriends if SearchLimitation.too_many_friends?(twitter_user: persisted_twitter_user)
    raise MaybeImportBatchFailed if persisted_twitter_user.no_need_to_import_friendships?

    latest_twitter_user = nil
    ApplicationRecord.benchmark("#{self.class} #{id} Create twitter_user", level: :info) do
      latest_twitter_user = create_twitter_user
    end

    changes = unfollowers_changed = nil
    ApplicationRecord.benchmark("#{self.class} #{id} Setup parameters", level: :info) do
      if latest_twitter_user
        changes = {followers_count: [persisted_twitter_user.follower_uids.size, latest_twitter_user.follower_uids.size]}
        previous_uids = persisted_twitter_user.calc_unfollower_uids
        current_uids = latest_twitter_user.unfollowerships.pluck(:follower_uid)
        unfollowers_changed = previous_uids != current_uids
      else
        latest_twitter_user = persisted_twitter_user
        changes = {followers_count: [persisted_twitter_user.follower_uids.size, latest_twitter_user.follower_uids.size]}
        unfollowers_changed = false
      end
    end

    ApplicationRecord.benchmark("#{self.class} #{id} Send report", level: :info) do
      send_report!(changes, previous_twitter_user: persisted_twitter_user, current_twitter_user: latest_twitter_user, changed: unfollowers_changed)
    end
  end

  def validate!
    verify_credentials!

    if twitter_user_not_exist?
      if initialization_started?
        raise TwitterUserNotPersisted
      else
        send_initialization_message!
      end
    end

    raise TooShortRequestInterval if too_short_request_interval?
    raise Unauthorized unless user.authorized?
    raise ReportDisabled unless user.dm_enabled?
    raise TooShortSendInterval unless user.dm_interval_ok?
    raise UserInactive unless user.active?(14)

    raise UserSuspended if suspended?
    raise TooManyFriends if SearchLimitation.too_many_friends?(user: user)
    raise EgotterBlocked if blocked?
  end

  def create_twitter_user
    create_request = CreateTwitterUserRequest.create(
        requested_by: 'report',
        user_id: user.id,
        uid: user.uid)

    created_user = nil
    ApplicationRecord.benchmark("#{self.class} #{id} create task start", level: :info) do
     created_user = CreateTwitterUserTask.new(create_request).start!.twitter_user
    end

    # TODO Create TwitterDB::User of imported uids

    ApplicationRecord.benchmark("#{self.class} #{id} Unfriendship.import_by!", level: :info) do
      Unfriendship.import_by!(twitter_user: created_user)
    end

    ApplicationRecord.benchmark("#{self.class} #{id} Unfollowership.import_by!", level: :info) do
      Unfollowership.import_by!(twitter_user: created_user)
    end

    created_user
  rescue CreateTwitterUserRequest::NotChanged, CreateTwitterUserRequest::RecentlyUpdated, CreateTwitterUserRequest::TooManyFriends => e
    nil
  rescue => e
    logger.warn "#{self.class} #{e.class} #{e.message} CreateTwitterUserTask is failed. #{create_request.inspect}"
    logger.info e.backtrace.join("\n")
    nil
  end

  def send_initialization_message!
    DirectMessageRequest.new(internal_client, User::EGOTTER_UID, I18n.t('dm.promptReportNotification.initialization_start')).perform
    DirectMessageRequest.new(User.egotter.api_client.twitter, user.uid, I18n.t('dm.promptReportNotification.search_yourself', screen_name: user.screen_name, url: search_yourself_url)).perform

    raise InitializationStarted
  rescue Twitter::Error::Forbidden => e
    if temporarily_dm_exception?(e)
      if blocked_exception?(e)
        CreateBlockedUserWorker.perform_async(user.uid, user.screen_name)
      end
    else
      logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
      logger.info e.backtrace.join("\n")
    end

    raise InitializationFailed.new(e.message.truncate(100))
  rescue InitializationStarted => e
    raise
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")

    raise InitializationFailed.new(e.message.truncate(100))
  end

  def search_yourself_url
    Rails.application.routes.url_helpers.timeline_url(screen_name: user.screen_name, via: 'prompt_report_search_yourself')
  end

  def send_report!(changes, previous_twitter_user:, current_twitter_user:, changed: true)
    if changed
      PromptReport.you_are_removed(user.id, changes_json: changes.to_json,
                                   previous_twitter_user: previous_twitter_user, current_twitter_user: current_twitter_user).deliver
    else
      PromptReport.not_changed(user.id, changes_json: changes.to_json,
                               previous_twitter_user: previous_twitter_user, current_twitter_user: current_twitter_user).deliver
    end
  rescue Twitter::Error::Forbidden => e
    if temporarily_dm_exception?(e)
      if blocked_exception?(e)
        CreateBlockedUserWorker.perform_async(user.uid, user.screen_name)
      end
    elsif not_allowed_to_access_or_delete_dm_exception?(e)
      # https://twittercommunity.com/t/updates-to-app-permissions-direct-message-write-permission-change/128221
    else
      logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect} #{changes.inspect}"
      logger.info e.backtrace.join("\n")
    end

    raise DirectMessageNotSent.new("#{e.class}: #{e.message.truncate(100)}")
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect} #{changes.inspect}"
    logger.info e.backtrace.join("\n")

    raise DirectMessageNotSent.new("#{e.class}: #{e.message.truncate(100)}")
  end

  private

  def verify_credentials!
    ApiClient.do_request_with_retry(internal_client, :verify_credentials, [])
  rescue Twitter::Error::Unauthorized => e
    if e.message == 'Invalid or expired token.'
      raise Unauthorized
    else
      logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
      logger.info e.backtrace.join("\n")
      raise Unknown.new(e.message)
    end
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")
    raise Unknown.new(e.message)
  end

  def twitter_user_not_exist?
    !TwitterUser.exists?(uid: user.uid)
  end

  def initialization_started?
    CreatePromptReportLog.where(user_id: user_id).pluck(:error_class).any? {|err| err.include? 'Initialization' }
  end

  INTERVAL = 30.minutes

  def too_short_request_interval?
    self.class.where(user_id: user.id, created_at: INTERVAL.ago..Time.zone.now).
        where.not(id: id).exists?
  end

  def suspended?
    fetch_user[:suspended]
  end

  def blocked?
    if BlockedUser.exists?(uid: fetch_user[:id])
      true
    else
      blocked = client.blocked_ids.include? User::EGOTTER_UID
      CreateBlockedUserWorker.perform_async(fetch_user[:id], fetch_user[:screen_name]) if blocked
      blocked
    end
  rescue Twitter::Error::Forbidden => e
    if e.message.start_with?('To protect our users from spam and other malicious activity, this account is temporarily locked.')
      raise TemporarilyLocked.new(__method__.to_s)
    else
      logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
      logger.info e.backtrace.join("\n")
      raise Unknown.new(e.message)
    end
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")
    raise Unknown.new(e.message)
  end

  def temporarily_dm_exception?(ex)
    if ex.class == Twitter::Error::Forbidden
      ex.message == 'You cannot send messages to users you have blocked.' ||
          ex.message == 'You cannot send messages to users who are not following you.' ||
          ex.message == 'You are sending a Direct Message to users that do not follow you.' ||
          ex.message == 'You cannot send messages to this user.' ||
          ex.message == "This request looks like it might be automated. To protect our users from spam and other malicious activity, we can't complete this action right now. Please try again later."
    end
  end

  def not_allowed_to_access_or_delete_dm_exception?(ex)
    if ex.class == Twitter::Error::Forbidden
      ex.message == 'This application is not allowed to access or delete your direct messages.'
    end
  end

  def blocked_exception?(ex)
    ex.class == Twitter::Error::Forbidden && ex.message == 'You cannot send messages to users you have blocked.'
  end

  def fetch_user
    @fetch_user ||= client.user(user.uid)
  rescue Twitter::Error::Forbidden => e
    if e.message.start_with? 'To protect our users from spam and other malicious activity, this account is temporarily locked.'
      raise TemporarilyLocked.new(__method__.to_s)
    else
      logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
      logger.info e.backtrace.join("\n")
      raise Unknown.new(e.message)
    end
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")
    raise Unknown.new(e.message)
  end

  def friend_uids_and_follower_uids
    client.friend_ids_and_follower_ids(user.uid)
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")
    raise Unknown.new(e.message)
  end

  def client
    @client ||= user.api_client
  end

  def internal_client
    @internal_client ||= client.twitter
  end

  class Error < StandardError
  end

  class DeadErrorTellsNoTales < Error
    def initialize(*args)
      super('')
    end
  end

  class TwitterUserNotPersisted < DeadErrorTellsNoTales
  end

  class InitializationStarted < DeadErrorTellsNoTales
  end

  class InitializationFailed < Error
  end

  class TooShortRequestInterval < DeadErrorTellsNoTales
  end

  class TooShortSendInterval < DeadErrorTellsNoTales
  end

  class Unauthorized < DeadErrorTellsNoTales
  end

  class Forbidden < DeadErrorTellsNoTales
  end

  class ReportDisabled < DeadErrorTellsNoTales
  end

  class UserInactive < DeadErrorTellsNoTales
  end

  class UserSuspended < DeadErrorTellsNoTales
  end

  class TooManyFriends < DeadErrorTellsNoTales
  end

  class TemporarilyLocked < Error
  end

  class EgotterBlocked < DeadErrorTellsNoTales
  end

  class MaybeImportBatchFailed < DeadErrorTellsNoTales
  end

  class UnfollowersNotChanged < DeadErrorTellsNoTales
  end

  class MessageNotChanged < DeadErrorTellsNoTales
  end

  class FollowersCountNotChanged < DeadErrorTellsNoTales
  end

  class RemovedUidNotChanged < DeadErrorTellsNoTales
  end

  class DirectMessageNotSent < Error
  end

  class Unknown < StandardError
  end
end
