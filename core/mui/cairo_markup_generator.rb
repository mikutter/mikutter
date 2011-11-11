# -*- coding: utf-8 -*-

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

  ESCAPE_KEYS = Regexp::union(*Pango::ESCAPE_RULE.keys.freeze)
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
    splited = message.to_show.gsub(ESCAPE_KEYS, &ESCAPE_KV)
      links.reverse_each{ |l|
        splited[l[:range]] = '<span underline="single" underline_color="#000000">'+"#{Pango.escape(l[:face])}</span>" }
    splited end

  # [[MatchData, 開始位置と終了位置のRangeオブジェクト(文字数), Regexp], ...] の配列を返す
  def links
    return message.links.to_a
    result = Set.new
    Gtk::TimeLine.linkrules.keys.each{ |regexp|
      main_text.each_matches(regexp){ |match, pos|
        if not result.any?{ |this| this[1].include?(pos) }
          pos = [escaped_main_text.size, pos].min
          result << [match, Range.new(pos, pos + match.to_s.size, true), regexp] end } }
    result.sort_by{ |r| r[1].first }.freeze end

end
