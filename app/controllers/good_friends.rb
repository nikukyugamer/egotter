class GoodFriends < ::Base
  include TweetTextHelper

  before_action(only: %i(all)) { valid_screen_name? && !not_found_screen_name? && !forbidden_screen_name? }
  before_action(only: %i(all)) { @tu = build_twitter_user(params[:screen_name]) }
  before_action(only: %i(all)) { authorized_search?(@tu) }
  before_action(only: %i(all)) { existing_uid?(@tu.uid.to_i) }
  before_action(only: %i(all)) { twitter_db_user_persisted?(@tu.uid.to_i) }
  before_action(only: %i(all)) { too_many_searches? }
  before_action(only: %i(all))  do
    @twitter_user = TwitterUser.latest(@tu.uid.to_i)
    remove_instance_variable(:@tu)
  end
  before_action(only: %i(all)) do
    push_referer
    create_search_log
  end

  def all
    unless user_signed_in?
      via = "#{controller_name}/#{action_name}/need_login"
      redirect = send("all_#{controller_name}_path", @twitter_user)
      return redirect_to sign_in_path(via: via, redirect_path: redirect)
    end
    initialize_instance_variables
    @collection = @twitter_user.send(controller_name)
  end

  def show
    initialize_instance_variables
  end

  private

  def initialize_instance_variables
    @api_path = send("api_v1_#{controller_name}_list_path")
    @breadcrumb_name, @canonical_url =
      if action_name == 'show'
        [controller_name.singularize.to_sym, send("#{controller_name.singularize}_url", @twitter_user)]
      else
        ["all_#{controller_name}".to_sym, send("all_#{controller_name}_url", @twitter_user)]
      end

    @page_title = t('.page_title', user: @twitter_user.mention_name)
    @meta_title = t('.meta_title', {user: @twitter_user.mention_name})

    users = @twitter_user.send(controller_name).limit(5)

    @page_description = t('.page_description', user: @twitter_user.mention_name)
    @meta_description = t('.meta_description', users: honorific_names(users.map(&:mention_name)))

    @tweet_text = good_friends_text(users, @twitter_user)

    @stat = UsageStat.find_by(uid: @twitter_user.uid)
  end

  def good_friends_text(users, twitter_user)
    mention_names = users.map.with_index { |u, i| "#{i + 1}. #{mention_name(u.screen_name)}" }
    t('.tweet_text', user: mention_name(twitter_user.screen_name), users: mention_names.join("\n"), url: @canonical_url)
  end
end