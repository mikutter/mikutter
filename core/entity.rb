# -*- coding: utf-8 -*-

class Message::Entity
  include Enumerable

  attr_reader :message

=begin rdoc
  { :media => [{ :indices => first..last, # リンクを貼る場所
                 :type => 'photo',
                 :media_url => '画像URL',
                 :url => 'リンクするURL' }],
    :urls => [{ :indices => first..last,
                :url => 'リンクするURL' }],
    :user => [{ :indices => first..last,
                :user => User }],
    :hashtag =>[{ :indices => first..last, # 「#」は含まない
                  :text => 'ハッシュタグ名(#は含まない)'
                }]
  }
=end

  @@linkrule = {}

  def self.addlinkrule(slug, regexp, &callback)
    slug = slug.to_sym
    @@linkrule[slug] = { :slug => slug, :regexp => regexp, :callback => callback }.freeze
    self end

  def initialize(message)
    type_strict message => Message
    @message = message
  end

  def each
    to_a.each(&Proc.new)
  end

  # [{range: リンクを貼る場所のRange, face: 表示文字列, url:リンク先}, ...] の配列を返す
  # face: TLに印字される文字列。
  # url: 実際のリンク先。本当にURLになるかはリンクの種類に依存する。
  #      例えばハッシュタグ "#mikutter" の場合はこの内容は "mikutter" になる。
  def to_a
    result = Set.new
    @@linkrule.values.each{ |rule|
      message.to_show.each_matches(rule[:regexp]){ |match, pos|
        if not result.any?{ |this| this[:range].include?(pos) }
          pos = message.to_show[0, pos].strsize
          result << rule.merge({:range => Range.new(pos, pos + match.to_s.strsize, true), :face => match.to_s, :url => match.to_s}).freeze end } }
    result.sort_by{ |r| r[:range].first }.freeze end
  memoize :links

end
