# frozen_string_literal: true

module ConcurrentExecutionHelper
  extend ActiveSupport::Concern

  # future_execute에 pool_size를 1로 해서 사용해도 되지만, 사용할 때 직관적으로 받아들이기 쉽게 하기 위해 추가로 함수 정의함.
  def single_thread_execute(enumerable)
    raise 'no block given' unless block_given?

    success_count = 0
    failure = []

    enumerable.each do |item|
      yield item
      success_count += 1
    rescue => e
      failure << { id: item.respond_to?(:id) ? item.id : item, err: e.message }
    end

    {success_count: success_count, failure: failure}
  end


  def future_execute(enumerable, pool_size)
    raise 'no block given' unless block_given?

    success_count = 0
    failure = []

    pool = Concurrent::FixedThreadPool.new(pool_size)

    futures = enumerable.map do |item|
      Concurrent::Promises.future_on(pool) do
        val = yield item
        success_count += 1
        val
      rescue => e
        failure << { id: item.respond_to?(:id) ? item.id : item, err: e.message }
        nil
      end
    end

    result = futures.map(&:value)
    pool.shutdown

    {result: result, success_count: success_count, failure: failure}
  end

  
  def thread_execute(enumerable, batch_size)
    raise 'no block given' unless block_given?

    success_count = 0
    failure = []

    chunks = chunk_fetch(enumerable, batch_size)

    threads = chunks.map do |items|
      Thread.new do
        items.each do |item|
          yield item
          success_count += 1
        rescue => e
          failure << { id: item.respond_to?(:id) ? item.id : item, err: e.message }
        end
      end
    end

    threads.each(&:join)
    {success_count: success_count, failure: failure}
  end


  def chunk_fetch(enumerable, batch_size)
    chunks =
      if enumerable.respond_to? :find_in_batches
        enumerable.find_in_batches(batch_size: batch_size)
      else
        enumerable.each_slice(batch_size)
      end
    chunks
  end

end