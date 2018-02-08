# -*- coding: utf-8 -*-

require 'gtk2'
miquire :lib, 'diva_hacks'

module Pango
  class << self

    # テキストをPango.parse_markupで安全にパースできるようにエスケープする。
    def escape(text)
      text.gsub(/[<>&]/){|m| Diva::Entity::BasicTwitterEntity::ESCAPE_RULE[m] } end

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
  def description_attr_list(attr_list=Pango::AttrList.new)
    gap = 0
    message.links.each do |l|
      underline = Pango::AttrUnderline.new(Pango::Underline::SINGLE)
      actual_start = l[:range].first
      actual_end = l[:range].last
      faced_start = actual_start + gap
      faced_end = faced_start + l[:face].size
      gap += faced_end - actual_end
      underline.start_index = plain_description[0...faced_start].bytesize
      underline.end_index = plain_description[0...faced_end].bytesize
      attr_list.insert(underline)
    end
    attr_list
  end

  # Entityを適用したあとのプレーンテキストを返す。
  def plain_description
    splited = message.to_show.dup
    message.links.to_a.reverse_each do |l|
      splited[l[:range]] = l[:face]
    end
    splited
  end

end
