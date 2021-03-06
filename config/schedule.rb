job_type :rake, 'cd :path && :environment_variable=:environment bundle exec rake :task --silent :output'
set :path, '~/egotter'
set :output, '~/egotter/log/crontab.log'
set :environment, :development

every 5.minutes do
  rake 'update_job_dispatcher:run'
end

every 15.minutes do
  command 'monit monitor all'
end

every 1.hour do
 command 'rm -rf /home/ec2-user/egotter/tmp/api_cache/$(date -d "2 hour ago" "+%Y%m%d%H")'
end

# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
