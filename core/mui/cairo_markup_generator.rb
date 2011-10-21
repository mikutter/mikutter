# -*- coding: utf-8 -*-

=begin rdoc
  本文の、描画するためのテキストを生成するモジュール。
=end
module Gdk::MarkupGenerator

  # 本文を返す
  def main_text
    message.to_show
  end

  # 本文のタグをエスケープしたものを返す
  def escaped_main_text
    Pango.escape(main_text) end

  # リンクに装飾をつけた文字列の配列を返す。だいたい一文字づつに分かれてる。
  def styled_main_array
    splited = message.to_show.split(//u).map{ |s| Pango::ESCAPE_RULE[s] || s }
      links.reverse_each{ |l|
        splited[l[:range]] = '<span underline="single" underline_color="#000000">'+"#{Pango.escape(l[:face])}</span>"
      }
    splited end

  # Gdk::MarkupGenerator#styled_main_array をjoinした文字列
  def styled_main_text
    styled_main_array.join end

  # [[MatchData, 開始位置と終了位置のRangeオブジェクト(文字数), Regexp], ...] の配列を返す
  def links
    return message.links.to_a
    result = Set.new
    Gtk::TimeLine.linkrules.keys.each{ |regexp|
      main_text.each_matches(regexp){ |match, pos|
        if not result.any?{ |this| this[1].include?(pos) }
          pos = escaped_main_text[0, pos].strsize
          result << [match, Range.new(pos, pos + match.to_s.strsize, true), regexp] end } }
    result.sort_by{ |r| r[1].first }.freeze end

end
