Sidekiq::Logging.logger.level = Logger::DEBUG

module JobCallbackUtil
  def send_callback(context, method_name, args)
    if context.respond_to?(method_name)
      context.send(method_name, *args)
    end
  rescue => e
    context.logger.warn "#{e.class}: #{e.message} #{context.class} #{method_name} #{args.inspect.truncate(100)}"
    context.logger.info e.backtrace.join("\n")
  end
end

module UniqueJobUtil
  include JobCallbackUtil

  def perform(worker, args, queue, &block)
    if worker.respond_to?(:unique_key)
      options = args.dup.extract_options!
      unique_key = worker.unique_key(*args)

      if !options['skip_unique'] && queue.exists?(unique_key)
        worker.logger.info "#{self.class}:#{worker.class} Skip duplicate job. #{args.inspect.truncate(100)}"

        send_callback(worker, :after_skip, args)

        return false
      end

      queue.add(unique_key)
    end

    yield
  end
end

class SidekiqServerUniqueJob
  include UniqueJobUtil

  def initialize(queue_class)
    @queue_class = queue_class
  end

  def call(worker, msg, queue, &block)
    perform(worker, msg['args'], @queue_class.new(worker.class), &block)
  end
end

class SidekiqClientUniqueJob
  include UniqueJobUtil

  def initialize(queue_class)
    @queue_class = queue_class
  end

  def call(worker_class, job, queue, redis_pool, &block)
    if job.has_key?('at')
      yield
    else
      worker_class = worker_class.constantize
      perform(worker_class.new, job['args'], @queue_class.new(worker_class), &block)
    end
  end
end

class SidekiqTimeoutJob
  include JobCallbackUtil

  def call(worker, msg, queue)
    if worker.respond_to?(:timeout_in)
      begin
        Timeout.timeout(worker.timeout_in) do
          yield
        end
      rescue Timeout::Error => e
        worker.logger.info "#{e.class}: #{e.message} #{worker.timeout_in} #{msg['args'].inspect.truncate(100)}"
        worker.logger.info e.backtrace.join("\n")

        send_callback(worker, :after_timeout, msg['args'])
      end
    else
      yield
    end
  end
end

class SidekiqExpireJob
  def call(worker, msg, queue)
    if worker.respond_to?(:expire_in)
      options = msg['args'].dup.extract_options!

      if options['enqueued_at'].blank?
        worker.logger.warn {"enqueued_at not found. #{msg['args'].inspect.truncate(100)}"}
      else
        if Time.zone.parse(options['enqueued_at']) < Time.zone.now - worker.expire_in
          worker.logger.info {"Skip expired job. #{msg['args'].inspect.truncate(100)}"}
          return false
        end
      end
    end
    yield
  end
end

Sidekiq.configure_server do |config|
  config.redis = {url: "redis://#{ENV['REDIS_HOST']}:6379"}
  config.server_middleware do |chain|
    chain.add SidekiqServerUniqueJob, RunningQueue
    chain.add SidekiqExpireJob
    chain.add SidekiqTimeoutJob
  end
  config.client_middleware do |chain|
    chain.add SidekiqClientUniqueJob, QueueingRequests
  end
end

Sidekiq.configure_client do |config|
  config.redis = {url: "redis://#{ENV['REDIS_HOST']}:6379"}
  config.client_middleware do |chain|
    chain.add SidekiqClientUniqueJob, QueueingRequests
  end
end