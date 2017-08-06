module ScoresHelper
  def find_or_create_score(uid)
    score = Score.find_by(uid: uid)

    unless score
      if request.from_crawler?
        score = Score.new(uid: uid, influence_json: {influencers: [], influencees: []}.to_json)
      else
        begin
          score = Score.builder(uid).build
          score.save! if score.valid? # It currently validates only klout_id.
        rescue => e
          logger.warn "Score of #{uid} is invalid. #{e.class} #{e.message.truncate(100)}"
        end
      end
    end

    score
  end
end
