# sidekiq-batch를 위한 커스텀 미들웨어
# 실패한 job argument 와 실패사유 저장

class SidekiqBatchServerMiddleware
  def call(_worker, msg, _queue)
    if (bid = msg['bid']) && (args = msg['args'])
      begin
        yield
        Sidekiq.redis {|r| r.hincrby("BID-#{bid}", "success_count", 1)}
      rescue => exception
        body = { args: args, err: exception.message }.to_json
        Sidekiq.redis {|r| r.sadd("BID-#{bid}-failed-arguments", body)}
        raise
      end
    else
      yield
    end
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add SidekiqBatchServerMiddleware
  end
end
