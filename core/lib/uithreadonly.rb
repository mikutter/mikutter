# -*- coding: utf-8 -*-

require 'set'

# このモジュールをincludeすると、そのクラスの全てのメソッドは
module UiThreadOnly
  PREFIX = 'qawsedrftgyhujikolp_'.freeze

  def self.included(klass)

    klass.instance_eval{

      class << self
        defined = Set.new
        define_method(:mainthread_only){ |method_name|
          if not(defined.include?(method_name.to_sym)) and not(method_name.to_s.start_with?(UiThreadOnly::PREFIX))
            defined << method_name.to_sym
            new_method = :"#{UiThreadOnly::PREFIX}#{method_name}"
            alias_method(new_method, method_name)
            define_method(method_name) { |*args, &proc|
              raise ThreadError.new("call #{self.class}##{method_name} not at main thread.") if Thread.current != Thread.main
              __send__(new_method, *args, &proc) } end }
      end

      (public_instance_methods - Class.new.public_instance_methods).each{ |method_name|
        mainthread_only method_name
      }

      def method_added(method_name)
        mainthread_only method_name
      end
    }
  end
end

deprecate_constant(:UiThreadOnly)
