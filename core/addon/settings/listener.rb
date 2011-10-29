# -*- coding: utf-8 -*-

class Plugin::Setting::Listener
  def self.[](symbol)
    return symbol if(symbol.is_a? Plugin::Setting::Listener)
    Plugin::Setting::Listener.new( :get => lambda{ UserConfig[symbol] },
                                   :set => lambda{ |val| UserConfig[symbol] = val }) end

  # ==== Args
  # [defaults]
  #   以下の値を含む連想配列。どちらか、またはどちらも省略して良い
  #   _get_ :: _get_.callで値を返すもの
  #   _set_ :: _set_.call(val)で値をvalに設定するもの
  def initialize(default = {})
    value = nil
    if default.has_key?(:get)
      @getter = default[:get]
    else
      @getter = lambda{ value } end
    if default.has_key?(:set)
      @setter = lambda{ |new| default[:set].call(value = new) }
    else
      @setter = lambda{ |new| value = new } end end

  def get
    @getter.call end

  def set(value)
    @setter.call(value) end

end
