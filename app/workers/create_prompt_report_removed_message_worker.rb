class CreatePromptReportRemovedMessageWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'messaging', retry: 0, backtrace: false

  def unique_key(user_id, options = {})
    user_id
  end

  def after_skip(user_id, options = {})
    log(Hashie::Mash.new(options)).update(status: false, error_class: CreatePromptReportRequest::RemovedMessageNotSent, error_message: "#{self.class} #{CreatePromptReportRequest::DuplicateJobSkipped}")
  end

  # options:
  #   changes_json
  #   previous_twitter_user_id
  #   current_twitter_user_id
  #   create_prompt_report_request_id
  def perform(user_id, options = {})
    user = User.find(user_id)
    unless user.authorized?
      log(options).update(status: false, error_class: CreatePromptReportRequest::RemovedMessageNotSent, error_message: "#{self.class} #{CreatePromptReportRequest::Unauthorized}")
      return
    end

    PromptReport.you_are_removed(
        user.id,
        changes_json: options['changes_json'],
        previous_twitter_user: TwitterUser.find(options['previous_twitter_user_id']),
        current_twitter_user: TwitterUser.find(options['current_twitter_user_id'])
    ).deliver!


    if !user.active_access?(CreatePromptReportRequest::ACTIVE_DAYS_WARNING)
      WarningMessage.inactive(user.id).deliver!
    elsif !user.following_egotter?
      WarningMessage.not_following(user.id).deliver!
    end

  rescue => e
    if TemporaryDmLimitation.temporarily_locked?(e)
    elsif TemporaryDmLimitation.you_have_blocked?(e)
      CreateBlockedUserWorker.perform_async(user.uid, user.screen_name)
    elsif TemporaryDmLimitation.not_allowed_to_access_or_delete_dm?(e)
    else
      logger.warn "#{e.class} #{e.message} #{user_id} #{options.inspect}"
      logger.info e.backtrace.join("\n")
    end

    ex = CreatePromptReportRequest::RemovedMessageNotSent.new("#{e.class}: #{e.message}")
    log(options).update(status: false, error_class: ex.class, error_message: ex.message)
  end

  def log(options)
    CreatePromptReportLog.find_or_initialize_by(request_id: options['create_prompt_report_request_id'])
  end
end
