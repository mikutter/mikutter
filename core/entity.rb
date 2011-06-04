# -*- coding: utf-8 -*-
miquire :core, 'message'

class Message::Entity
  include Enumerable

  attr_reader :message

  @@linkrule = {}
  @@filter = Hash.new(ret_nth)

  def self.addlinkrule(slug, regexp, &callback)
    slug = slug.to_sym
    @@linkrule[slug] = { :slug => slug, :regexp => regexp, :callback => callback }.freeze
    self end

  def self.filter(slug, &filter)
    parent = @@filter[slug]
    @@filter[slug] = lambda{ |s| filter.call(parent.call(s)) }
    self end

  filter(:urls){ |segment|
    if UserConfig[:shrinkurl_expand]
      if segment[:expanded_url]
        segment[:face] = segment[:expanded_url]
      elsif MessageConverters.shrinkable_url_regexp === segment[:url]
        segment[:face] = MessageConverters.expand_url([segment[:url]])[segment[:url]] end end
    segment }

  def initialize(message)
    type_strict message => Message
    @message = message
    @generate_thread = Thread.new{
      @generate_value = _generate_value || []
      def self.generate_value
        @generate_value end
      @generate_thread = nil } end

  def each
    to_a.each(&Proc.new)
  end

  def reverse_each
    to_a.reverse.each(&Proc.new)
  end

  # [{range: リンクを貼る場所のRange, face: 表示文字列, url:リンク先}, ...] の配列を返す
  # face: TLに印字される文字列。
  # url: 実際のリンク先。本当にURLになるかはリンクの種類に依存する。
  #      例えばハッシュタグ "#mikutter" の場合はこの内容は "mikutter" になる。
  def to_a
    generate_value end

  # entityフィルタを適用した状態のMessageの本文を返す
  def to_s
    segment_splitted.map{ |s|
      if s.is_a? Hash
        s[:face]
      else
        s end }.join end

  # _index_ 文字目のエンティティの要素を返す。エンティティでなければnilを返す
  def segment_by_index(index)
    segment_text.each{ |segment|
      if segment.is_a? Integer
        index -= segment
      elsif segment.is_a? Hash
        index -= segment[:face].strsize
      end
      if index < 0
        if segment.is_a? Hash
          return segment
        else
          return nil end end } end

  private

  def segment_splitted
    result = message.to_show.split(//u)
    reverse_each{ |segment|
      result[segment[:range]] = segment }
    result.freeze end
  memoize :segment_splitted

  def segment_text
    result = []
    segment_splitted.each{ |segment|
      if segment.is_a? String
        if result.last.is_a? Integer
          result[-1] += 1
        else
          result << 1 end
      elsif segment.is_a? Hash
        result << segment end }
    result.freeze end
  memoize :segment_text

  def generate_value
    @generate_thread.join
    @generate_value end

  def _generate_value
    result = Set.new(message_entities)
    @@linkrule.values.each{ |rule|
      message.to_show.each_matches(rule[:regexp]){ |match, pos|
        if not result.any?{ |this| this[:range].include?(pos) }
          pos = message.to_show[0, pos].strsize
          result << @@filter[rule[:slug]].call(rule.merge({ :message => message,
                                                            :range => Range.new(pos, pos + match.to_s.strsize, true),
                                                            :face => match.to_s,
                                                            :url => match.to_s})).freeze end } }
    result.sort_by{ |r| r[:range].first }.freeze end


  # Messageオブジェクトに含まれるentity情報を、 Message::Entity#to_a と同じ形式で返す。
  def message_entities
    result = Set.new
    if message[:entities]
      message[:entities].each{ |slug, children|
        children.each{ |link|
          rule = @@linkrule[slug] || {}
          range = indices_to_range(link[:indices])
          face = (message.to_show.split(//u)[range] || '').join
          result << @@filter[slug].call(rule.merge({ :message => message,
                                                     :range => range,
                                                     :face => face,
                                                     :url => face}.merge(link))).freeze } } end
    result.sort_by{ |r| r[:range].first }.freeze end
  memoize :message_entities

  def indices_to_range(indices)
    Range.new(index_to_escaped_index(indices[0]), index_to_escaped_index(indices[1]-1), false) end

  def index_to_escaped_index(index)
    message.to_show.split(//u)[0, index].map{ |s| Pango::ESCAPE_RULE[s] || s }.join.strsize
    # Pango.escape(message.body.split(//u)[0, index].join).strsize
  end

end
