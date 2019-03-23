module Plugin::Worldon
  class Util
    class << self
      def deep_dup(obj)
        Marshal.load(Marshal.dump(obj))
      end

      def ppf(obj)
        pp obj
        $stdout.flush
      end
    end
  end
end
