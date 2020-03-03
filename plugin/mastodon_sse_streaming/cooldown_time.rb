# frozen_string_literal: true

module Plugin::MastodonSseStreaming
  class CooldownTime
    DURATION_NONE = 0
    DURATION_MIN = 1
    DURATION_MAX = 64

    def initialize
      @duration = DURATION_NONE
    end

    def sleep
      Kernel.sleep(@duration) if @duration != 0
    end

    def reset
      @duration = DURATION_NONE
    end

    def meltdown
      @duration = DURATION_MAX
    end

    def status_code(code)
      case code
      when 410      then meltdown # Gone 二度と戻ってくることはないだろう
      when 200..300 then reset
      when 400..500 then client_error
      when 500..600 then server_error
      else               client_error
      end
    end

    def client_error
      modify(@duration + 0.25)
    end

    def server_error
      modify(@duration * 2)
    end

    def modify(d)
      @duration = d.clamp(DURATION_MIN, DURATION_MAX)
    end
  end
end
