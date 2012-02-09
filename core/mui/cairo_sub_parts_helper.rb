# -*- coding: utf-8 -*-
miquire :lib, 'uithreadonly'
miquire :core, 'userconfig'

require 'gtk2'
require 'cairo'

module Gdk::SubPartsHelper

  def initialize(*args)
    @subparts_height = nil
    super end

  # 今サポートされている全てのSubPartsを配列で返す
  # ==== Return
  # Subpartsクラスの配列
  def self.subparts_classes
    @subparts_classes ||= [] end

  def subparts
    @subparts ||= Gdk::SubPartsHelper.subparts_classes.map{ |klass| klass.new(self) } end

  def render_parts(context)
    context.save{
      mainpart_height
      context.translate(0, mainpart_height)
      subparts.each{ |part|
        context.save{
          part.render(context) }
        context.translate(0, part.height) } }
    self end

  def subparts_height
    result = _subparts_height
    reset_height if(@subparts_height != result)
    @subparts_height = result end

  private

  def _subparts_height
    subparts.inject(0){ |sum, part| sum + part.height } end end

class Gdk::SubParts
  include UiThreadOnly

  attr_reader :helper

  def self.regist
    index = where_should_insert_it(self.to_s, Gdk::SubPartsHelper.subparts_classes.map(&:to_s), UserConfig[:subparts_order] || [])
    Gdk::SubPartsHelper.subparts_classes.insert(index, self)
  end

  def initialize(helper)
    @helper = helper
  end

  def render(context)
  end

  def width
    helper.width end

  def height
    0 end

  def dummy_context
    Gdk::Pixmap.new(nil, 1, 1, @helper.color).create_cairo_context end

end
