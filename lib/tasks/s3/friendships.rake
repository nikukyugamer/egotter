namespace :s3 do
  namespace :friendships do
    desc 'Write friendships to file'
    task write_to_file: :environment do
      sigint = false
      Signal.trap 'INT' do
        puts 'intercept INT and stop ..'
        sigint = true
      end

      start_id = ENV['START'] ? ENV['START'].to_i : 1
      start = Time.zone.now
      processed_count = 0

      TwitterUser.includes(:friendships).select(:id, :uid, :screen_name).find_in_batches(start: start_id, batch_size: 100) do |group|
        S3::Friendship.write_to_file(group)
        processed_count += group.size
        puts "#{now = Time.zone.now} #{group.last.id} #{(now - start) / processed_count}"

        break if sigint
      end

      puts Time.zone.now - start
    end

    desc 'Write friendships to S3'
    task write_to_s3: :environment do
      sigint = false
      Signal.trap 'INT' do
        puts 'intercept INT and stop ..'
        sigint = true
      end

      start_id = ENV['START'] ? ENV['START'].to_i : 1
      start = Time.zone.now
      processed_count = 0

      TwitterUser.includes(:friendships).select(:id, :uid, :screen_name).find_in_batches(start: start_id, batch_size: 100) do |group|
        S3::Friendship.import!(group)
        processed_count += group.size
        puts "#{now = Time.zone.now} #{group.last.id} #{(now - start) / processed_count}"

        break if sigint
      end

      puts Time.zone.now - start
    end
  end
end