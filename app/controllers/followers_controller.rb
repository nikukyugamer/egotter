class FollowersController < ::Page::FriendsAndFollowers
  def all
    super
    render template: 'friends/all' unless performed?
  end

  def show
    super
    @active_tab = 1
    render template: 'friends/show' unless performed?
  end

  private

  def related_counts
    values = {}

    Timeout.timeout(2.seconds) do
      values[:followers] = @twitter_user.follower_uids.size
      values[:one_sided_followers] = @twitter_user.one_sided_followerships.size
      values[:one_sided_followers_rate] = (@twitter_user.one_sided_followers_rate * 100).round(1)
    end

    values
  rescue Timeout::Error => e
    logger.info "#{controller_name}##{__method__} #{e.class} #{e.message} #{@twitter_user.inspect}"
    logger.info e.backtrace.join("\n")

    values[:followers] = -1 unless values.has_key?(:followers)
    values[:one_sided_followers] = -1 unless values.has_key?(:one_sided_followers)
    values[:one_sided_followers_rate] = -1 unless values.has_key?(:one_sided_followers_rate)

    values
  end

  def tabs
    [
      {text: t('friends.show.see_friends_html', num: @twitter_user.friend_uids.size), url: friend_path(@twitter_user)},
      {text: t('friends.show.see_followers_html', num: @twitter_user.follower_uids.size), url: follower_path(@twitter_user)}
    ]
  end
end
