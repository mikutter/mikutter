# -*- coding: utf-8 -*-

require 'gtk2'

module Pango
  ESCAPE_RULE = {'&' => '&amp;' ,'>' => '&gt;', '<' => '&lt;'}.freeze
  class << self

    # テキストをPango.parse_markupで安全にパースできるようにエスケープする。
    def escape(text)
      text.gsub(/[<>&]/){|m| Pango::ESCAPE_RULE[m] } end

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

  ESCAPE_KEYS = Regexp::union(*Pango::ESCAPE_RULE.keys)
  ESCAPE_KV = Pango::ESCAPE_RULE.method(:[])

  # 本文を返す
  def main_text
    message.to_show
  end

  # 本文のタグをエスケープしたものを返す
  def escaped_main_text
    Pango.escape(main_text) end

  # リンクに装飾をつけた文字列の配列を返す。だいたい一文字づつに分かれてる。
  def styled_main_text
    splited = message.to_show.dup
    terminate = splited.size
    message.links.to_a.reverse_each{ |l|
      escape_range = l[:range].last ... terminate
      splited[escape_range] = splited[escape_range].gsub(ESCAPE_KEYS, &ESCAPE_KV)
      splited[l[:range]] = '<span underline="single">'+"#{Pango.escape(l[:face])}</span>"
      terminate = l[:range].first
    }
    splited[0...terminate] = splited[0...terminate].gsub(ESCAPE_KEYS, &ESCAPE_KV) if terminate != 0
    splited end

end
