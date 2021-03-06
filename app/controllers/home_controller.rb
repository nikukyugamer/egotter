class HomeController < ApplicationController
  include Concerns::JobQueueingConcern

  before_action do
    push_referer

    if session[:sign_in_from].present?
      create_search_log(referer: session.delete(:sign_in_from))
    elsif session[:sign_out_from].present?
      create_search_log(referer: session.delete(:sign_out_from))
    else
      create_search_log
    end
  end

  def new
    enqueue_update_authorized

    if params[:back_from_twitter] == 'true'
      flash.now[:notice] = t('before_sign_in.back_from_twitter_html', url: sign_in_path(via: "#{controller_name}/#{action_name}/back_from_twitter"))
    end

    if flash.empty? && user_signed_in? && TwitterUser.exists?(uid: current_user.uid)
      redirect_path = timeline_path(screen_name: current_user.screen_name)
      redirect_path = append_query_params(redirect_path, follow_dialog: params[:follow_dialog]) if params[:follow_dialog]
      redirect_path = append_query_params(redirect_path, share_dialog: params[:share_dialog]) if params[:share_dialog]
      redirect_to redirect_path
    end
  end
end
