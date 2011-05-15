# -*- coding: utf-8 -*-

def Gdk::SubPartsHelper(*subparts_classes)
  subparts_classes.freeze
  Module.new{
    define_method(:subparts){
      @subparts ||= subparts_classes.map{ |klass| klass.new(self) }
    }

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
      subparts.inject(0){ |sum, part| sum + part.height } end

  } end

class Gdk::SubParts

  attr_reader :helper

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
    Gdk::Pixmap.new(nil, 1, 1, 24).create_cairo_context end

end
