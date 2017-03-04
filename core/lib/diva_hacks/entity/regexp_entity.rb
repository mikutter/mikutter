# -*- coding: utf-8 -*-
require_relative 'blank_entity'

module Diva::Entity

=begin rdoc
特定の正規表現にマッチする部分を自動的にSegmentにするEntity。

==== Example

    class Sample < Diva::Model
      entity_class Diva::Entity::RegexpEntity.
        filter(/:(?:\w+):/, ->s{ s.merge(open: 'https://...') }). # :???: をクリックされたら対応する絵文字の画像(https://...)を開く
        filter(/@(?:\w+)/, ->s{ s.merge(open: "https://twitter.com/#{s[:url]}") }) # @??? をクリックされたらTwitterでユーザページを開く
    end

=end
  class RegexpEntity < BlankEntity
    class << self
      # 正規表現ルールを定義する
      # ==== Args
      # [regexp] Regexp Segmentを自動生成するための正規表現
      # [generator:]
      # Proc テキストを装飾する範囲を表わすHashを引数として受け取って、それを加工して返すProc。
      # 引数はHashひとつだけで、加工する必要がなければ、引数の内容をそのまま返す。
      # ===== Argument of generator
      # 引数 _generator:_ のProcに渡されるHashは、以下のキーを持つ
      # [:message] Diva::Model このEntityが装飾する本文を持っているModel
      # [:range] Range 装飾する範囲（文字数）。
      # [:face] String _:message_ の本文中の _range_ の範囲にあるテキスト。これを書き換えると、実際の本文は変わらないが、表示上はこの内容に置き換わる。
      # [:url] String 歴史的経緯でこのような名前になっているがURLとは限らない。_:message_ の本文中の _range_ の範囲にあるテキスト。 _:face_ と違って、書き換わる前の内容が格納されている。
      # [:open] Diva::Model|URI|nil デフォルトでは存在しない。内容を指定すると、UI上で本文の _:range_ の範囲がクリックされた時に、 :open イベントでそれを開くようになる。
      # [:callback] Proc|nil 利用は非推奨。できるだけ _:open_ を使う。デフォルトでは存在しない。内容を指定すると、UI上で本文の _:range_ の範囲がクリックされた時に、これが呼ばれるようになる。指定されている場合、 _:open_ より優先される。
      # ==== Return
      # Class その正規表現を自動でリンクにする新しいEntityクラス
      def filter(regexp, generator: ret_nth)
        Class.new(self) do
          define_method(:initialize) do |*rest|
            super(*rest)
            segments = Set.new(@generate_value)
            self.message.to_show.scan(regexp) do
              match = Regexp.last_match
              pos = match.begin(0)
              body = match.to_s.freeze
              if not segments.any?{ |this| this[:range].include?(pos) }
                segments << generator.(
                  message: message,
                  from: :regexp,
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
