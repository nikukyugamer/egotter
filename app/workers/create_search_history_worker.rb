class CreateSearchHistoryWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'misc', retry: 0, backtrace: false

  def perform(session_id, user_id, uid, ahoy_visit_id = nil)
    condition = (user_id == -1) ? {session_id: session_id} : {user_id: user_id}
    latest = SearchHistory.order(created_at: :desc).find_by(condition)

    if !latest || latest.uid != uid
      SearchHistory.create!(session_id: session_id, user_id: user_id, uid: uid, ahoy_visit_id: ahoy_visit_id)
    end
  rescue => e
    logger.warn "#{e.class}: #{e.message} #{session_id} #{user_id} #{uid}"
  end
end