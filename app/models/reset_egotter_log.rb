# == Schema Information
#
# Table name: reset_egotter_logs
#
#  id            :bigint(8)        not null, primary key
#  error_class   :string(191)      default(""), not null
#  error_message :string(191)      default(""), not null
#  message       :string(191)      default(""), not null
#  screen_name   :string(191)      default(""), not null
#  status        :boolean          default(FALSE), not null
#  uid           :string(191)      default("-1"), not null
#  created_at    :datetime         not null
#  session_id    :string(191)      default(""), not null
#  user_id       :integer          default(-1), not null
#
# Indexes
#
#  index_reset_egotter_logs_on_created_at  (created_at)
#

class ResetEgotterLog < ApplicationRecord
  validates :session_id, presence: true
  validates :uid, presence: true
  validates :screen_name, presence: true
end