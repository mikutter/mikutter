# -*- coding: utf-8 -*-

module Plugin::Settings
  # Setting DSLの、入れ子になったsettingsだけを抜き出すためのクラス。
  class Phantom
    attr_reader :detected

    def initialize(plugin_slug, &block)
      @plugin_slug = plugin_slug
      @detected = Array.new
      begin
        instance_eval(&block)
      rescue
        @detected = [].freeze
      end
      @detected.freeze
    end

    Gtk::FormDSL.instance_methods.each do |name|
      define_method(name) do |*|
        MOCK
      end
    end

    def settings(name, &block)
      @detected << Record.new(name, block, @plugin_slug)
    end

    def method_missing(name, *rest, &block)
      case name.to_sym
      when *Gtk::FormDSL.instance_methods
        MOCK
      else
        Plugin.instance(@plugin_slug).__send__(name, *rest, &block)
      end
    end

    class Mock
      def method_missing(name, *rest, **kwrest, &block)
        MOCK
      end
    end

    MOCK = Mock.new

  end

end
