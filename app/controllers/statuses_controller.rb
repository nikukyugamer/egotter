class StatusesController < ApplicationController
  include Concerns::SearchByUidConcern

  def show
    statuses = @twitter_user.statuses.limit(20)
    @statuses = statuses.select(&:user)

    if statuses.size != @statuses.size
      logger.warn "Status doesn't have user. Continue to rendering #{@twitter_user.inspect}"
    end
  end
end
