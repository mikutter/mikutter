# -*- coding: utf-8 -*-

require 'gtk2'
miquire :lib, 'diva_hacks'

module Pango
  ESCAPE_RULE = {'&': '&amp;'.freeze ,'>': '&gt;'.freeze, '<': '&lt;'.freeze}.freeze
  class << self

    # テキストをPango.parse_markupで安全にパースできるようにエスケープする。
    def escape(text)
      text.gsub(/[<>&]/){|m| ESCAPE_RULE[m] }
    end

    alias old_parse_markup parse_markup

    # パースエラーが発生した場合、その文字列をerrorで印字する。
    def parse_markup(str)
      begin
        old_parse_markup(str)
      rescue GLib::Error => e
        error str
        raise e end end end end

=begin rdoc
  本文の、描画するためのテキストを生成するモジュール。
=end

module Gdk::MarkupGenerator
  # 表示する際に本文に適用すべき装飾オブジェクトを作成する
  # ==== Return
  # Pango::AttrList 本文に適用する装飾
  def description_attr_list(attr_list=Pango::AttrList.new, emoji_height: 24)
    Plugin[:gtk].score_of(message).inject(0){|start_index, note|
      end_index = start_index + note.description.bytesize
      if note.respond_to?(:inline_photo)
        end_index += -note.description.bytesize + 1
        rect = Pango::Rectangle.new(0, 0, emoji_height * Pango::SCALE, emoji_height * Pango::SCALE)
        shape = Pango::AttrShape.new(rect, rect, note.inline_photo)
        shape.start_index = start_index
        shape.end_index = end_index
        attr_list.insert(shape)
      elsif clickable?(note)
        underline = Pango::AttrUnderline.new(Pango::Underline::SINGLE)
        underline.start_index = start_index
        underline.end_index = end_index
        attr_list.insert(underline)
      end
      end_index
    }
    attr_list
  end

  def clickable?(model)
    has_model_intent = Enumerator.new {|y| Plugin.filtering(:intent_select_by_model_slug, model.class.slug, y) }.first
    return true if has_model_intent
    Enumerator.new {|y|
      Plugin.filtering(:model_of_uri, model.uri, y)
    }.any?{|model_slug|
      Enumerator.new {|y| Plugin.filtering(:intent_select_by_model_slug, model_slug, y) }.first
    }
  end

  # Entityを適用したあとのプレーンテキストを返す。
  # Pangoの都合上、絵文字は1文字で表現する
  def plain_description
    Plugin[:gtk].score_of(message).map{|note|
      if note.respond_to?(:inline_photo)
        '.'
      else
        note.description
      end
    }.to_a.join
  end

end
