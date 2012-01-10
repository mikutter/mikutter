# -*- coding: utf-8 -*-
module Escape
  module_function

  class StringWrapper
    class << self
      alias new_no_dup new
      def new(str)
        new_no_dup(str.dup)
      end
    end

    def initialize(str)
      @str = str
    end

    def to_s
      @str.dup
    end

    def inspect
      "\#<#{self.class}: #{@str}>"
    end

    def ==(other)
      other.class == self.class && @str == other.instance_variable_get(:@str)
    end
    alias eql? ==

    def hash
      @str.hash
    end
  end

  class ShellEscaped < StringWrapper
  end

  def shell_command(command)
    s = command.map {|word| shell_single_word(word) }.join(' ')
    ShellEscaped.new_no_dup(s)
  end

  class PercentEncoded < StringWrapper
  end

  # Escape.uri_segment escapes URI segment using percent-encoding.
  # It returns an instance of PercentEncoded.
  #
  #  Escape.uri_segment("a/b") #=> #<Escape::PercentEncoded: a%2Fb>
  #
  # The segment is "/"-splitted element after authority before query in URI, as follows.
  #
  #   scheme://authority/segment1/segment2/.../segmentN?query#fragment
  #
  # See RFC 3986 for details of URI.
  def uri_segment(str)
    # pchar - pct-encoded = unreserved / sub-delims / ":" / "@"
    # unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
    # sub-delims = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
    s = str.gsub(%r{[^A-Za-z0-9\-._~!$&'()*+,;=:@]}n) { #'#"
      '%' + $&.unpack("H2")[0].upcase
    }
    PercentEncoded.new_no_dup(s)
  end

  def query_segment(str)
    # pchar - pct-encoded = unreserved / sub-delims / ":" / "@"
    # unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
    # sub-delims = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
    s = str.gsub(%r{[^A-Za-z0-9_]}n) { #'#"
      '%' + $&.unpack("H2")[0].upcase
    }
    PercentEncoded.new_no_dup(s)
  end

  # Escape.uri_path escapes URI path using percent-encoding.
  # The given path should be a sequence of (non-escaped) segments separated by "/".
  # The segments cannot contains "/".
  # It returns an instance of PercentEncoded.
  #
  #  Escape.uri_path("a/b/c") #=> #<Escape::PercentEncoded: a/b/c>
  #  Escape.uri_path("a?b/c?d/e?f") #=> #<Escape::PercentEncoded: a%3Fb/c%3Fd/e%3Ff>
  #
  # The path is the part after authority before query in URI, as follows.
  #
  #   scheme://authority/path#fragment
  #
  # See RFC 3986 for details of URI.
  #
  # Note that this function is not appropriate to convert OS path to URI.
  def uri_path(str)
    s = str.gsub(%r{[^/]+}n) { uri_segment($&) }
    PercentEncoded.new_no_dup(s)
  end
end
