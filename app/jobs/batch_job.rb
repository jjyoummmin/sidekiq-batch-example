class BatchJob
  include Sidekiq::Worker
  include ConcurrentExecutionHelper

  def initialize(job_class, description="", queue="default")
    @job_class = job_class
    @queue = queue

    @batch = Sidekiq::Batch.new
    @bid = @batch.bid

    @batch.description = description
    @batch.on(:complete, BatchJob::Callback, bid: @bid, job_class: job_class)
    @batch.on(:success, BatchJob::Callback, bid: @bid, job_class: job_class)
  end

  def push_jobs(enumerable, batch_size)
    # argument 계산을 위한 block 필요
    raise 'job argument block needed' unless block_given?
    return unless enumerable&.any? == true

    total_count = 0
    chunks = chunk_fetch(enumerable, batch_size)

    @batch.jobs do
      chunks.each do |items|
        arguments = yield items
        Sidekiq::Client.push_bulk('class' => @job_class, 'args' => arguments, 'queue' => @queue)
        total_count += items.count
      end
    end

    Sidekiq.redis {|r| r.hset("BID-#{@bid}", "size", total_count)}
    @job_class.constantize.send_start_message(@batch.description, total_count)
  end

  class Callback
    def on_complete(status, options)
      return if status.failures == 0

      bid = options.fetch('bid')
      job_class = options.fetch('job_class')

      description, total_count, success_count, failed_arguments = Sidekiq.redis do |r|
        r.multi do |pipeline|
          pipeline.hget("BID-#{bid}", 'description')
          pipeline.hget("BID-#{bid}", 'size')
          pipeline.hget("BID-#{bid}", 'success_count')
          pipeline.smembers("BID-#{bid}-failed-arguments")
          pipeline.del("BID-#{bid}-failed-arguments")
        end
      end
      success_count ||= 0
      failed_arguments = failed_arguments.map {|x| JSON.parse(x) }

      job_class.constantize.send_end_message(description, total_count, failed_arguments)
    end

    def on_success(status, options)
      bid = options.fetch('bid')
      job_class = options.fetch('job_class')

      description, total_count, success_count = Sidekiq.redis do |r|
        r.multi do |pipeline|
          pipeline.hget("BID-#{bid}", 'description')
          pipeline.hget("BID-#{bid}", 'size')
          pipeline.hget("BID-#{bid}", 'success_count')
        end
      end

      job_class.constantize.send_end_message(description, total_count)
    end
  end
end