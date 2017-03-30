# == Schema Information
#
# Table name: jobs
#
#  id              :integer          not null, primary key
#  user_id         :integer          default(-1), not null
#  uid             :integer          default(-1), not null
#  screen_name     :string(191)      default(""), not null
#  twitter_user_id :integer          default(-1), not null
#  client_uid      :integer          default(-1), not null
#  jid             :string(191)      default(""), not null
#  parent_jid      :string(191)      default(""), not null
#  worker_class    :string(191)      default(""), not null
#  error_class     :string(191)      default(""), not null
#  error_message   :string(191)      default(""), not null
#  enqueued_at     :datetime
#  started_at      :datetime
#  finished_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_jobs_on_created_at   (created_at)
#  index_jobs_on_jid          (jid)
#  index_jobs_on_screen_name  (screen_name)
#  index_jobs_on_uid          (uid)
#

class Job < ActiveRecord::Base
  def error?
    !!error_class
  end
end