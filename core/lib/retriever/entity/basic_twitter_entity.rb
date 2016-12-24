# -*- coding: utf-8 -*-
require_relative 'regexp_entity'

module Retriever::Entity
  class BasicTwitterEntity < RegexpEntity
    ESCAPE_RULE = {'&' => '&amp;'.freeze ,'>' => '&gt;'.freeze, '<' => '&lt;'.freeze}.freeze
    UNESCAPE_RULE = ESCAPE_RULE.invert.freeze
    # REGEXP_EACH_CHARACTER = //u.freeze
    REGEXP_ENTITY_ENCODE_TARGET = Regexp.union(*ESCAPE_RULE.keys.map(&Regexp.method(:escape))).freeze
    REGEXP_ENTITY_DECODE_TARGET = Regexp.union(*ESCAPE_RULE.values.map(&Regexp.method(:escape))).freeze
    # screen nameにマッチする正規表現
    MentionMatcher      = /(?:@|＠|〄|☯|⑨|♨)([a-zA-Z0-9_]+)/.freeze

    # screen nameのみから構成される文字列から、@などを切り取るための正規表現
    MentionExactMatcher = /\A(?:@|＠|〄|☯|⑨|♨)?([a-zA-Z0-9_]+)\Z/.freeze

    def initialize(*_rest)
      super
      set_message_entities
    end

    private
    def set_message_entities
      @generate_value = message_entities
    end

    def message_entities
      result = Set.new
      return result if not message[:entities]
      message[:entities].each do |slug, twitter_entity_objects|
        twitter_entity_objects.each do |link|
          begin
            rule = {}
            extended_entities = matched_extended_entites(slug, link[:display_url])
            if extended_entities.empty?
              result << normal_entity(slug, link).freeze
            else
              entities_from_extended_entities(link, extended_entities, message: message, slug: slug, rule: rule).each do |converted_entity|
                converted_entity[:range] = get_range_by_face(converted_entity)
                result << converted_entity.freeze end
            end
          rescue Retriever::InvalidEntityError, RuntimeError => exception
            error exception end
        end
      end
      result.to_a.compact.sort_by{ |r| r[:range].first }.freeze
    end

    def normal_entity(slug, entity)
      entity = { from: :twitter,
                 slug: slug
               }.merge(entity)
      case slug
      when :urls
        entity[:face] = (entity[:display_url] or entity[:url])
        entity[:url] = (entity[:expanded_url] or entity[:url])
        entity[:open] = entity[:url]
      when :user_mentions
        entity[:face] = entity[:url] = "@#{entity[:screen_name]}".freeze
        user = Retriever::Model(:twitter_user)
        if user
          entity[:open] = user.findbyidname(entity[:screen_name], Retriever::DataSource::USE_LOCAL_ONLY) ||
                          Retriever::URI.new("https://twitter.com/#{entity[:screen_name]}")
        else
          entity[:open] = Retriever::URI.new("https://twitter.com/#{entity[:screen_name]}")
        end
      when :hashtags
        entity[:face] = entity[:url] = "##{entity[:text]}".freeze
        twitter_search = Retriever::Model(:twitter_search)
        if twitter_search
          entity[:open] = twitter_search.new(query: "##{entity[:text]}") end
      when :media
        case entity[:video_info] and entity[:type]
        when 'video'
          variant = Array(entity[:video_info][:variants])
                    .select{|v|v[:content_type] == "video/mp4"}
                    .sort_by{|v|v[:bitrate]}
                    .last
          entity[:face] = "#{entity[:display_url]} (%.1fs)" % (entity[:video_info][:duration_millis]/1000.0)
          entity[:open] = entity[:url] = variant[:url]
        when 'animated_gif'
          variant = Array(entity[:video_info][:variants])
                    .select{|v|v[:content_type] == "video/mp4"}
                    .sort_by{|v|v[:bitrate]}
                    .last
          entity[:face] = "#{entity[:display_url]} (GIF)"
          entity[:open] = entity[:url] = variant[:url]
        else
          entity[:face] = entity[:display_url]
          entity[:url] = entity[:media_url]
          photo = Retriever::Model(:photo)
          if photo
            entity[:open] = photo[entity[:media_url]]
          else
            entity[:open] = entity[:media_url]
          end
        end
      else
        error "Unknown entity slug `#{slug}' was detected."
        return
      end
      entity.merge(range: get_range_by_face(entity))
    end

    # slug と　display_url が一致するextended entitiesを返す
    # ==== Args
    # [slug] Symbol Entityのスラッグ
    # [display_url] String 探すExtended Entityのdisplay_url
    # ==== Return
    # Extended Entityの配列。見つからなかった場合は空の配列
    def matched_extended_entites(slug, display_url)
      if defined?(message[:extended_entities][slug]) and message[:extended_entities][slug].is_a? Array
        message[:extended_entities][slug].select do |link|
          display_url == link[:display_url] end
      else
        [] end end

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

    # source_entity に対する extended_entity を、通常のエンティティに変換して返す。
    # source_entity のテキスト上の表現の1文字にextended_entityの1つを割り当て、最後のextended_entity
    # には残りの全てを割り当てる。
    # ==== Args
    # [source_entity] Hash 元となるエンティティ
    # [extended_entities] Array Extended Entity
    # ==== Return
    # entityの配列
    def entities_from_extended_entities(source_entity, extended_entities, slug: source_entity[:slug], rule:, message: nil)
      type_strict source_entity => Hash, extended_entities => Array, slug => Symbol
      result = extended_entities.map.with_index do |extended_entity, index|
        entity_rewrite = {
          display_url: extended_entity[:media_url],
          indices: [source_entity[:indices][0]+index, source_entity[:indices][0]+index+1] }
        if 0 != index
          entity_rewrite[:display_url] = "\n#{entity_rewrite[:display_url]}" end
        normal_entity(slug, extended_entity.merge(entity_rewrite)) end
      result.last[:indices][1] = source_entity[:indices][1]
      result end

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

  end
end
