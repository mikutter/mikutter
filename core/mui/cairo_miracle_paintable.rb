require 'gtk2'

module Gtk::MiraclePaintable
  ObjectSpec = Struct.new(:klass, :id)

  # Decode the result of _painter_key_ and returns ObjectSpec
  def self.decode_painter_key(key)
    klass_name, id_str = key.split('#')
    ObjectSpec.new(Object.const_get(klass_name), id_str.to_i)
  end

  def painter_key
    "#{self.class}##{self[:id]}"
  end
end

class Message
  include Gtk::MiraclePaintable
end
