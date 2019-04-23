module Plugin::Worldon
  # https://docs.joinmastodon.org/api/entities/#poll-option
  class PollOption < Diva::Model
    register :worldon_poll_option, name: "Mastodon投票候補(Worldon)"

    field.string :title, required: true
    field.int :votes_count

    def path
      "/#{title}"
    end

    def inspect
      "worldon-poll-option(#{title}, #{votes_count})"
    end
  end

  # https://docs.joinmastodon.org/api/entities/#poll
  class Poll < Diva::Model
    register :worldon_poll, name: "Mastodon投票(Worldon)"

    field.string :id, required: true
    field.time :expires_at
    field.bool :expired, required: true
    field.bool :multiple, required: true
    field.int :votes_count, required: true
    field.has :options, [PollOption], required: true
    field.bool :voted

    def initialize(hash)
      if hash[:expires_at].is_a?(String)
        hash[:expires_at] = Time.parse(hash[:expires_at]).localtime
      end

      super hash
    end

    def path
      "/#{id}"
    end

    def inspect
      "worldon-poll(#{id})"
    end
  end
end
