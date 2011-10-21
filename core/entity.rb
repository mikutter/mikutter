# -*- coding: utf-8 -*-
miquire :core, 'message'
miquire :core, 'userconfig'
miquire :lib, 'addressable/uri'

class Message::Entity
  include Enumerable

  attr_reader :message

  @@linkrule = {}
  @@filter = Hash.new(ret_nth)

  def self.addlinkrule(slug, regexp=nil, &callback)
    slug = slug.to_sym
    @@linkrule[slug] = { :slug => slug, :regexp => regexp, :callback => callback }.freeze
    self end

  def self.filter(slug, &filter)
    parent = @@filter[slug]
    @@filter[slug] = lambda{ |s|
      result = filter.call(parent.call(s))
      [:url, :face].each{ |key|
        raise InvalidEntityError.new("entity key :#{key} required. but not exist.", message) unless result[key] }
      result }
    self end

  filter(:urls){ |segment|
    segment[:face] ||= segment[:url]
    if UserConfig[:shrinkurl_expand]
      if segment[:expanded_url]
        begin
          normalized = Addressable::URI.parse('//'+segment[:display_url]).display_uri.to_s
          segment[:face] = normalized[2, normalized.size]
        rescue => e
          error e
          segment[:face] = segment[:display_url] end
      elsif MessageConverters.shrinkable_url_regexp === segment[:url]
        segment[:face] = segment[:expanded_url] = MessageConverters.expand_url([segment[:url]])[segment[:url]] end end
    segment }

  filter(:media){ |segment|
    segment[:face] = segment[:display_url]
    segment[:url] = segment[:media_url]
    segment }

  filter(:hashtags){ |segment|
    segment[:face] ||= "#"+segment[:text]
    segment[:url] ||= "#"+segment[:text]
    segment }

  filter(:user_mentions){ |segment|
    segment[:face] ||= "@"+segment[:screen_name]
    segment[:url] ||= "@"+segment[:screen_name]
    segment }

  def initialize(message)
    type_strict message => Message
    @message = message
    @generate_thread = Thread.new {
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
          return nil end end }
    nil end

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
      if rule[:regexp]
        message.to_show.each_matches(rule[:regexp]){ |match, byte, pos|
          if not result.any?{ |this| this[:range].include?(pos) }
            result << @@filter[rule[:slug]].call(rule.merge({ :message => message,
                                                              :range => Range.new(pos, pos + match.to_s.strsize, true),
                                                              :face => match.to_s,
                                                              :from => :_generate_value,
                                                              :url => match.to_s})).freeze end } end }
    result.sort_by{ |r| r[:range].first }.freeze end


  # Messageオブジェクトに含まれるentity情報を、 Message::Entity#to_a と同じ形式で返す。
  def message_entities
    result = Set.new
    if message[:entities]
      message[:entities].each{ |slug, children|
        children.each{ |link|
          rule = @@linkrule[slug] || {}
          entity = @@filter[slug].call(rule.merge({ :message => message,
                                                    :from => :message_entities}.merge(link)))
          entity[:range] = get_range_by_face(entity) #indices_to_range(link[:indices])
          result << entity.freeze } } end
    result.sort_by{ |r| r[:range].first }.freeze end

  def get_range_by_face(link)
    right = message.to_show.index(link[:url], link[:indices][0])
    left = message.to_show.rindex(link[:url], link[:indices][1])
    if right and left
      start = [right - link[:indices][0], left - link[:indices][0]].map(&:abs).min + link[:indices][0]
      start...(start + link[:url].size)
    elsif right or left
      start = right || left
      start...(start + link[:url].size)
    else
      indices_to_range(link[:indices]) end end

  def indices_to_range(indices)
    Range.new(index_to_escaped_index(indices[0]), index_to_escaped_index(indices[1]), true) end

  def index_to_escaped_index(index)
    escape_rule = {'>' => '&gt;', '<' => '&lt;'}
    message.to_show.split(//u).map{ |s|
      escape_rule[s] || s }.join.split(//u)[0, index].join.gsub(/&.+?;/, '.').strsize
  end

  class InvalidEntityError < Message::MessageError
  end

end
