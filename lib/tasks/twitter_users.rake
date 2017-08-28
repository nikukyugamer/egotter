namespace :twitter_users do
  desc 'create'
  task create: :environment do
    sigint = Util::Siging.new.trap

    persisted_uids = nil

    specified_uids =
      if ENV['UIDS']
        ENV['UIDS'].remove(/ /).split(',').map(&:to_i)
      else
        User.authorized.pluck(:uid).map(&:to_i).take(500)
     end

    failed = false
    processed = []
    skipped = 0
    skipped_reasons = []
    skip_if_persisted = ENV['SKIP'].present?

    specified_uids.each.with_index do |uid, i|
      if skip_if_persisted
        persisted_uids ||= TwitterUser.uniq.pluck(:uid).map(&:to_i)
        if persisted_uids.include?(uid)
          skipped += 1
          skipped_reasons << "Persisted #{uid}"
          next
        end
      end

      twitter_user = TwitterUser::Batch.fetch_and_create(uid)
      processed << twitter_user if twitter_user

      puts("#{i + 1}/#{specified_uids.size}") if (i % 100).zero?

      break if sigint.trapped? || failed
    end

    if processed.any?
      puts "\ncreated:"
      processed.take(500).each do |twitter_user|
        print "  #{twitter_user.uid} "
        twitter_user.debug_print_friends
      end
    end

    if skipped_reasons.any?
      puts "\nskipped reasons:"
      puts skipped_reasons.take(500).map { |r| "  #{r}" }.join("\n")
    end

    puts "\ncreate #{(sigint.trapped? || failed ? 'suspended:' : 'finished:')}"
    puts "  uids: #{specified_uids.size}, processed: #{processed.size}, skipped: #{skipped}"
  end
end
