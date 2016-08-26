# -*- coding: utf-8 -*-
require_relative 'blank_entity'

module Retriever::Entity

=begin rdoc
特定の正規表現にマッチする部分を自動的にSegmentにするEntity。
=end
  class RegexpEntity < BlankEntity
    class << self
      # 正規表現ルールを定義する
      # ==== Args
      # [regexp] Regexp Segmentを自動生成するための正規表現
      # [generator:] Proc Segmentを受け取って、加工して返すProc。以下の引数を受け取る
      #   segment :: 元になる _Segment_
      # [open:] Proc クリックされた時に呼び出される。以下の引数を受け取る
      #   entity :: Retriever::Entity::RegexpEntity 呼び出し元のEntity
      #   segment :: _generator_ が返した値
      # ==== Return
      # Class その正規表現を自動でリンクにする新しいEntityクラス
      def filter(regexp, generator:, open:)
        Class.new(self) do
          @@autolink_condition = regexp.freeze
          @@generator = generator
          @@open = open

          def initialize(*rest)
            super
            segments = Set.new(@generate_value)
            self.message.to_show.scan(@@autolink_condition) do
              match = Regexp.last_match
              pos = match.begin(0)
              body = match.to_s.freeze
              if not segments.any?{ |this| this[:range].include?(pos) }
                segments << @@generator.(
                  slug: :urls,
                  range: Range.new(pos, pos + body.size, true),
                  face: body,
                  url: body).freeze
              end
            end
            @generate_value = segments.sort_by{ |r| r[:range].first }.freeze
          end
        end
      end
    end

  end
end
