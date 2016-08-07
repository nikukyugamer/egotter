module ApplicationHelper
  def under_maintenance?
    ENV['MAINTENANCE'] == '1'
  end

  def redis
    @redis ||= Redis.client
  end

  def client
    @client ||= (user_signed_in? ? current_user.api_client : Bot.api_client)
  end

  def admin_signed_in?
    user_signed_in? && current_user.admin?
  end

  def search_oneself?(uid)
    user_signed_in? && current_user.uid.to_i == uid.to_i
  end

  def search_others?(uid)
    user_signed_in? && current_user.uid.to_i != uid.to_i
  end

  def current_user_id
    user_signed_in? ? current_user.id : -1
  end

  def egotter_share_text
    @egotter_share_text ||= t('tweet_text.top', kaomoji: Kaomoji.happy)
  end
end
