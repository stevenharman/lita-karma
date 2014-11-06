module Lita::Handlers::Karma
  class Decay
    include Lita::Handler::Common

    namespace "karma"

    def call
      return unless decay_enabled?
      cutoff = Time.now.to_i - decay_interval
      terms = redis.zrangebyscore(:actions, '-inf', cutoff).map { |json| decay_action(json) }
      delete_decayed(terms, cutoff)
    end

    private

    def decay_action(json)
      action = Action.from_json(json)
      redis.zincrby(:terms, -action.delta, action.term)
      redis.zincrby("modified:#{action.term}", -1, action.user_id) if action.user_id
      action.term
    end

    def decay_enabled?
      config.decay && decay_interval > 0
    end

    def decay_interval
      config.decay_interval
    end

    def delete_decayed(terms, cutoff)
      redis.zremrangebyscore(:actions, '-inf', cutoff)
      terms.each { |term| redis.zremrangebyscore("modified:#{term}", '-inf', 0) }
    end
  end
end