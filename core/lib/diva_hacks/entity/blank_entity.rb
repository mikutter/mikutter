# -*- coding: utf-8 -*-

module Diva::Entity
  class BlankEntity
    REGEXP_EACH_CHARACTER = //u.freeze

    include Enumerable

    attr_reader :message

    def initialize(message)
      @message = message
      @generate_value = [] end

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
      links.push(addition)
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
      @generate_value end

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

  end
end
