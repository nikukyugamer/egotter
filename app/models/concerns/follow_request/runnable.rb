require 'active_support/concern'

module Concerns::FollowRequest::Runnable
  extend ActiveSupport::Concern

  class_methods do
  end

  included do
    scope :finished, -> {where.not(finished_at: nil).where(error_class: '')}
    scope :not_finished, -> {where(finished_at: nil).where(error_class: '')}
  end

  def finished!
    update!(finished_at: Time.zone.now) if finished_at.nil?
  end

  def finished?
    !finished_at.nil?
  end
end
