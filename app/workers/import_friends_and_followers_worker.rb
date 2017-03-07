class ImportFriendsAndFollowersWorker
  include Sidekiq::Worker
  include Concerns::WorkerUtils
  sidekiq_options queue: self, retry: false, backtrace: false

  def perform(user_id, uid)
    client = user_id == -1 ? Bot.api_client : User.find(user_id).api_client
    @retry_count = 0

    signatures = [{method: :user, args: [uid]}, {method: :friends, args: [uid]}, {method: :followers, args: [uid]}]
    t_user, friends, followers = client._fetch_parallelly(signatures)
    users = []

    _benchmark('build friends') { users.concat(friends.map { |f| to_array(f) }) } if friends&.any?
    _benchmark('build followers') { users.concat(followers.map { |f| to_array(f) }) } if followers&.any?

    users << to_array(t_user)
    users.uniq!(&:first)
    users.sort_by!(&:first)

    _retry_with_transaction!('import TwitterDB::User') { TwitterDB::User.import_each_slice(users) }

    _retry_with_transaction!('import TwitterDB::Friendship and TwitterDB::Followership') do
      TwitterDB::Friendship.import_from!(uid, friends.map(&:id)) if friends&.any?
      TwitterDB::Followership.import_from!(uid, followers.map(&:id)) if followers&.any?
      TwitterDB::User.find_by(uid: uid).tap { |me| me.update_columns(friends_size: me.friendships.size, followers_size: me.followerships.size) }
    end

  rescue Twitter::Error::Unauthorized => e
    case e.message
      when 'Invalid or expired token.' then User.find_by(id: user_id)&.update(authorized: false)
      when 'Could not authenticate you.' then logger.warn "#{e.class} #{e.message} #{user_id} #{uid}"
      else logger.warn "#{e.class} #{e.message} #{user_id} #{uid}"
    end
  rescue ActiveRecord::StatementInvalid => e
    message = e.message.truncate(60)
    logger.warn "#{e.class} #{message} #{user_id} #{uid} #{@retry_count}"
    logger.info e.backtrace.join "\n"
  rescue => e
    message = e.message.truncate(150)
    logger.warn "#{e.class} #{message} #{user_id} #{uid} #{@retry_count}"
    logger.info e.backtrace.join "\n"
  ensure
    Rails.logger.info "[worker] #{self.class} finished. #{user_id} #{uid} #{t_user.screen_name}"
  end

  private

  def to_array(user)
    [user.id, user.screen_name, user.slice(*TwitterUser::PROFILE_SAVE_KEYS).to_json, -1, -1]
  end
end
