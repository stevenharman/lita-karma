require "spec_helper"

describe Lita::Handlers::Karma::Decay, lita_handler: true do
  def add_action(term, user_id, delta, time)
    action = Lita::Handlers::Karma::Action.new(term, user_id, delta, time)
    subject.redis.zadd(:actions, time.to_i, action.serialize)
  end

  prepend_before { registry.register_handler(Lita::Handlers::Karma::Config) }

  let(:term) { "foo" }

  describe '#call' do
    let(:mods) { { bar: 2, baz: 3, nil => 4 } }
    let(:offsets) { {} }

    before do
      registry.config.handlers.karma.decay = true
      registry.config.handlers.karma.decay_interval = 24 * 60 * 60

      subject.redis.zadd('terms', 8, term)
      subject.redis.zadd("modified:#{term}", mods.invert.to_a)
      mods.each do |mod, score|
        offset = offsets[mod].to_i
        score.times do |i|
          add_action(term, mod, 1, Time.now - (i + offset) * 24 * 60 * 60)
        end
      end
    end

    it 'should decrement scores' do
      subject.call

      expect(subject.redis.zscore(:terms, term).to_i).to eq(2)
    end

    it 'should remove decayed actions' do
      subject.call

      expect(subject.redis.zcard(:actions).to_i).to eq(3)
    end

    context 'with decayed modifiers' do
      let(:offsets) { { baz: 1 } }

      it 'should remove them' do
        subject.call

        expect(subject.redis.zcard("modified:#{term}")).to eq(2)
      end
    end
  end
end