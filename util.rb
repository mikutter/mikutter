module Plugin::Worldon
  class Util
    class << self
      def deep_dup(obj)
        Marshal.load(Marshal.dump(obj))
      end
    end
  end
end
