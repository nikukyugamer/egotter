require 'rails_helper'

RSpec.describe TwitterUserFetcher do
  let(:twitter_user) { TwitterUser.new(uid: 1, screen_name: 'sn', raw_attrs_text: {}.to_json) }
  let(:fetcher) { TwitterUserFetcher.new(twitter_user, client: nil, login_user: nil) }

  describe '#reject_relation_names' do
    context '#too_many_friends? returns true' do
      before { allow(SearchLimitation).to receive(:too_many_friends?).and_return(true) }

      it 'includes :friend_ids and :follower_ids' do
        candidates = fetcher.send(:reject_relation_names)
        expect(candidates).to be_include(:friend_ids)
        expect(candidates).to be_include(:follower_ids)
      end
    end
  end
end