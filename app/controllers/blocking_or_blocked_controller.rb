class BlockingOrBlockedController < ::Base
  include TweetTextHelper
  include WorkersHelper

  def show
    super

    counts = {
      unfriends: @twitter_user.unfriendships.size,
      unfollowers: @twitter_user.unfollowerships.size,
      blocking_or_blocked: @twitter_user.blocking_or_blocked_uids.size
    }

    @meta_title = t('.meta_title', {user: @twitter_user.mention_name}.merge(counts))

    @page_description = t('.page_description', user: @twitter_user.mention_name)
    @meta_description = t('.meta_description', {user: @twitter_user.mention_name}.merge(counts))

    uids = @twitter_user.blocking_or_blocked_uids.take(3)
    users = TwitterDB::User.where(uid: uids).index_by(&:uid)
    mention_names = uids.map { |uid| users[uid] }.compact.map(&:mention_name)
    names = '.' + honorific_names(mention_names)
    @tweet_text = t('.tweet_text', users: names, url: @canonical_url)

    @disabled_label = 2

    @jid = add_create_twitter_user_worker_if_needed(@twitter_user.uid, user_id: current_user_id, screen_name: @twitter_user.screen_name)

    render template: 'unfriends/show'
  end
end