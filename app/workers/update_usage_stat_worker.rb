class UpdateUsageStatWorker
  include Sidekiq::Worker
  include Concerns::WorkerUtils
  sidekiq_options queue: self, retry: 0, backtrace: false

  def perform(uid, options = {})
    queue = RunningQueue.new(self.class)
    return if queue.exists?(uid)
    queue.add(uid)

    if options['enqueued_at'].blank? || Time.zone.parse(options['enqueued_at']) < Time.zone.now - 10.minute
      logger.info {"Don't run this job since it is too late."}
      return
    end

    stat = UsageStat.find_by(uid: uid)
    return if stat&.fresh?

    twitter_user = TwitterUser.select(:uid, :screen_name).latest_by(uid: uid)
    statuses =
      if twitter_user.statuses.exists?
        twitter_user.statuses
      else
        user = User.find_by(id: options['user_id'])
        user = User.authorized.find_by(uid: uid) unless user
        client = user ? user.api_client : Bot.api_client
        client.user_timeline(uid.to_i).map { |s| TwitterDB::Status.build_by(twitter_user: twitter_user, status: s) }
      end

    if statuses.any?
      UsageStat.builder(uid).statuses(statuses).build.save!
    end
  rescue Twitter::Error::Unauthorized => e
    handle_unauthorized_exception(e, uid: uid)
  rescue => e
    logger.warn "#{e.class}: #{e.message} #{uid}"
    logger.info e.backtrace.join("\n")
  end
end
