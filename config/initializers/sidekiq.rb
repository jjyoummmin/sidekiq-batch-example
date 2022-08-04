redis_params = {
  url: "redis://localhost:6379",
}

# Server config
Sidekiq.configure_server do |config|
  config.redis = redis_params
end

# Client config
Sidekiq.configure_client do |config|
  config.redis = redis_params
end
