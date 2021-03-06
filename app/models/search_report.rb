# == Schema Information
#
# Table name: search_reports
#
#  id         :bigint(8)        not null, primary key
#  user_id    :integer          not null
#  read_at    :datetime
#  message_id :string(191)      not null
#  message    :string(191)      default(""), not null
#  token      :string(191)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_search_reports_on_created_at  (created_at)
#  index_search_reports_on_token       (token) UNIQUE
#  index_search_reports_on_user_id     (user_id)
#

class SearchReport < ApplicationRecord
  include Concerns::Report::HasToken
  include Concerns::Report::HasDirectMessage
  include Concerns::Report::Readable

  belongs_to :user

  def self.you_are_searched(user_id)
    new(user_id: user_id, token: generate_token)
  end

  def deliver
    DirectMessageRequest.new(user_client, User::EGOTTER_UID, I18n.t('dm.searchNotification.whats_happening', screen_name: screen_name)).perform
    button = {label: I18n.t('dm.searchNotification.timeline_page', screen_name: screen_name), url: timeline_url}
    resp = DirectMessageRequest.new(egotter_client, user.uid, build_message, [button]).perform
    dm = DirectMessage.new(resp)

    transaction do
      update!(message_id: dm.id, message: dm.truncated_message)
      user.notification_setting.update!(search_sent_at: Time.zone.now)
    end

    dm
  end

  private

  def user_client
    @user_client ||= user.api_client.twitter
  end

  def egotter_client
    @egotter_client ||= User.egotter.api_client.twitter
  end

  def screen_name
    user.screen_name
  end

  def build_message
    template = Rails.root.join('app/views/search_reports/you_are_searched.ja.text.erb')
    ERB.new(template.read).result_with_hash(screen_name: screen_name, url: timeline_url)
  end

  def timeline_url
    Rails.application.routes.url_helpers.timeline_url(screen_name: screen_name, token: token, medium: 'dm', type: 'search', via: 'search_report')
  end
end
