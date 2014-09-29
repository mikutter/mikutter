# -*- coding: utf-8 -*-
miquire :core, 'message'
miquire :core, 'userconfig'
miquire :lib, 'addressable/uri'

class Message::Entity
  ESCAPE_RULE = {'&' => '&amp;'.freeze ,'>' => '&gt;'.freeze, '<' => '&lt;'.freeze}.freeze
  UNESCAPE_RULE = ESCAPE_RULE.invert.freeze
  REGEXP_EACH_CHARACTER = //u.freeze
  REGEXP_ENTITY_ENCODE_TARGET = Regexp.union(*ESCAPE_RULE.keys.map(&Regexp.method(:escape))).freeze
  REGEXP_ENTITY_DECODE_TARGET = Regexp.union(*ESCAPE_RULE.values.map(&Regexp.method(:escape))).freeze

  include Enumerable

  attr_reader :message

  def self.addlinkrule(slug, regexp=nil, filter_id=nil, &callback)
    slug = slug.to_sym
    Plugin.call(:entity_linkrule_added, { slug: slug, filter_id: filter_id, regexp: regexp, callback: callback }.freeze)
    # Gtk::IntelligentTextview.addlinkrule(regexp, lambda{ |seg, tv| callback.call(face: seg, url: seg, textview: tv) }) if regexp
    self end

  def self.on_entity_linkrule_added(linkrule)
    @@linkrule[linkrule[:slug]] = linkrule
    self end

  def self.filter(slug, &filter)
    if @@filter.has_key?(slug)
      parent = @@filter[slug]
      @@filter[slug] = filter_wrap{ |s| filter.call(parent.call(s)) }
    else
      @@filter[slug] = filter_wrap &filter end
    self end

  def self.filter_wrap(&filter)
    ->(s) {
      result = filter.call(s)
      [:url, :face].each{ |key|
        if defined? result[:message]
          raise InvalidEntityError.new("entity key :#{key} required. but not exist", result[:message]) unless result[key]
        else
          raise RuntimeError, "entity key :#{key} required. but not exist" end }
      result } end

  def self.refresh
    @@linkrule = {}
    @@filter = Hash.new(filter_wrap(&ret_nth))
    filter(:urls){ |segment|
      segment[:face] = (segment[:display_url] or segment[:url])
      segment[:url] = (segment[:expanded_url] or segment[:url])
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
  end

  def initialize(message)
    type_strict message => Message
    @message = message
    @generate_thread = Thread.new {
      begin
        @generate_value = _generate_value || []
      rescue TimeoutError => e
        error "entity parse timeout. ##{message[:id]}(@#{message.user[:idname]}: #{message.to_show})"
        raise RuntimeError, "entity parse timeout. ##{message[:id]}(@#{message.user[:idname]}: #{message.to_show})"
      rescue Exception => e
        error e end
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

  # 外部からエンティティを書き換える。
  # これでエンティティが書き換えられた場合、イベントで書き換えが通知される。
  # また、エンティティの範囲が被った場合それを削除する
  # ==== Args
  # [addition] Hash 以下の要素を持つ配列
  #   - :slug (required) :: Symbol エンティティの種類。:urls 等
  #   - :url (required) :: String 実際のクエリ(リンク先URL等)
  #   - :face (required) :: String 表示する文字列
  #   - :range (required) :: Range message上の置き換える範囲
  #   - :message :: Message 親Message
  # ==== Return
  # self
  def add(addition)
    type_strict addition[:slug] => Symbol, addition[:url] => String, addition[:face] => String, addition[:range] => Range
    links = select{|link|
      (link[:range].to_a & addition[:range].to_a).empty?
    }
    links.push addition
    @generate_value = links.sort_by{ |r| r[:range].first }.freeze
    Plugin.call(:message_modified, message)
  end

  # _index_ 文字目のエンティティの要素を返す。エンティティでなければnilを返す
  def segment_by_index(index)
    segment_text.each{ |segment|
      if segment.is_a? Integer
        index -= segment
      elsif segment.is_a? Hash
        index -= segment[:face].size
      end
      if index < 0
        if segment.is_a? Hash
          return segment
        else
          return nil end end }
    nil end

  # "look http://example.com/" のようなツイートに対して、
  #  ["l", "o", "o", "k", " ", {エンティティのURLの値}]
  # のように、エンティティの情報を間に入れた配列にして返す。
  def segment_splitted
    result = message.to_show.split(REGEXP_EACH_CHARACTER)
    reverse_each{ |segment|
      result[segment[:range]] = segment }
    result.freeze end

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

  def generate_value
    @generate_thread.join if @generate_thread
    @generate_value end

  def _generate_value
    result = Set.new(message_entities)
    @@linkrule.values.each{ |rule|
      if rule[:regexp]
        message.to_show.scan(rule[:regexp]){
          match = Regexp.last_match
          pos = match.begin(0)
          body = match.to_s.freeze
          if not result.any?{ |this| this[:range].include?(pos) }
            result << @@filter[rule[:slug]].call(rule.merge({ :message => message,
                                                              :range => Range.new(pos, pos + body.size, true),
                                                              :face => body,
                                                              :from => :_generate_value,
                                                              :url => body})).freeze end } end }
    result.sort_by{ |r| r[:range].first }.freeze end


  # Messageオブジェクトに含まれるentity情報を、 Message::Entity#to_a と同じ形式で返す。
  def message_entities
    result = Set.new
    if message[:entities]
      message[:entities].each{ |slug, children|
        children.each{ |link|
          begin
            rule = @@linkrule[slug] || {}
            entity = @@filter[slug].call(rule.merge({ :message => message,
                                                      :from => :message_entities}.merge(link)))
            entity[:range] = get_range_by_face(entity) #indices_to_range(link[:indices])
            result << entity.freeze
          rescue InvalidEntityError, RuntimeError => exception
            error exception end } } end
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
    Range.new(self.class.index_to_escaped_index(message.to_show, indices[0]),
              self.class.index_to_escaped_index(message.to_show, indices[1]), true) end

  # to_showで得たエンティティデコードされた文字列の index が、
  # エンティティエンコードされた文字列ではどうなるかを返す。
  # ==== Args
  # [decoded_string] String デコードされた文字列
  # [encoded_index] Fixnum エンコード済み文字列でのインデックス
  # ==== Return
  # Fixnum デコード済み文字列でのインデックス
  def self.index_to_escaped_index(decoded_string, encoded_index)
    decoded_string
      .gsub(REGEXP_ENTITY_ENCODE_TARGET, &ESCAPE_RULE.method(:[]))
      .slice(0, encoded_index)
      .gsub(REGEXP_ENTITY_DECODE_TARGET, &UNESCAPE_RULE.method(:[]))
      .size end

  class InvalidEntityError < Message::MessageError
  end

  refresh

end
