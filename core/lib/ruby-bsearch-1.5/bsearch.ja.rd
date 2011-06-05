=begin
= Ruby/Bsearch: 配列を 2分探索する Ruby用のライブラリ

Ruby/Bsearch は配列を 2分探索する Ruby用のライブラリです。ブ
ロックで与えた条件にマッチする、最初の要素および最後の要素を
見つけます。

最新版は
((<URL:http://namazu.org/~satoru/ruby-bsearch/>))
から入手可能です

== 使用例

  % irb -r ./bsearch.rb
  >> %w(a b c c c d e f).bsearch_first {|x| x <=> "c"}
  => 2
  >> %w(a b c c c d e f).bsearch_last {|x| x <=> "c"}
  => 5
  >> %w(a b c e f).bsearch_first {|x| x <=> "c"}
  => 2
  >> %w(a b e f).bsearch_first {|x| x <=> "c"}
  => nil
  >> %w(a b e f).bsearch_last {|x| x <=> "c"}
  => nil
  >> %w(a b e f).bsearch_lower_boundary {|x| x <=> "c"}
  => 2
  >> %w(a b e f).bsearch_upper_boundary {|x| x <=> "c"}
  => 2
  >> %w(a b c c c d e f).bsearch_range {|x| x <=> "c"}
  => 2...5
  >> %w(a b c d e f).bsearch_range {|x| x <=> "c"}
  => 2...3
  >> %w(a b d e f).bsearch_range {|x| x <=> "c"}
  => 2...2

== 説明図

<<< figure

== API

--- Array#bsearch_first (ange = 0 ... self.length) {|x| ...}
    ブロックで与えた条件にマッチする最初の要素の添字を返す。見つ
    からなかったら nil を返す。省略可能な引数 range は検索範囲を
    指定する
    昇順の配列を探索する場合はブロックを {|x| x <=> key} のように渡します。
    降順の配列を探索する場合はブロックを {|x| key <=> x} のように渡します。
    当然のことながら、配列は2分探索の前にソートしておく必要があります。

--- Array#bsearch_last (range = 0 ... self.length) {|x| ...}
    ブロックで与えた条件にマッチする最後の要素の添字を返す。
    見つからなかったら nil を返す。省略可能な引数 range は検
    索範囲を指定する
    昇順の配列を探索する場合はブロックを {|x| x <=> key} のように渡します。
    降順の配列を探索する場合はブロックを {|x| key <=> x} のように渡します。
    当然のことながら、配列は2分探索の前にソートしておく必要があります。

--- Array#bsearch_lower_boundary (range = 0 ... self.length) {|x| ...}
    ブロックで与えた条件にマッチする下限の境界を返す。
    省略可能な引数 range は検索範囲を指定する
    昇順の配列を探索する場合はブロックを {|x| x <=> key} のように渡します。
    降順の配列を探索する場合はブロックを {|x| key <=> x} のように渡します。
    当然のことながら、配列は2分探索の前にソートしておく必要があります。

--- Array#bsearch_upper_boundary (range = 0 ... self.length) {|x| ...}
    ブロックで与えた条件にマッチする上限の境界を返す。
    省略可能な引数 range は検索範囲を指定する
    昇順の配列を探索する場合はブロックを {|x| x <=> key} のように渡します。
    降順の配列を探索する場合はブロックを {|x| key <=> x} のように渡します。
    当然のことながら、配列は2分探索の前にソートしておく必要があります。

--- Array#bsearch_range (range = 0 ... self.length) {|x| ...}
    ブロックで与えた条件にマッチする下限と上限の境界を
    Range オブジェクトとして返す。
    省略可能な引数 range は検索範囲を指定する
    昇順の配列を探索する場合はブロックを {|x| x <=> key} のように渡します。
    降順の配列を探索する場合はブロックを {|x| key <=> x} のように渡します。
    当然のことながら、配列は2分探索の前にソートしておく必要があります。

--- Array#bsearch (range = 0 ... self.length) {|x| ...}
    Array#bsearch_first の別名

== ダウンロード

Ruby のライセンスに従ったフリーソフトウェアとして公開します。
完全に無保証です。

  * ((<URL:http://namazu.org/~satoru/ruby-bsearch/ruby-bsearch-1.4.tar.gz>))
  * ((<URL:http://cvs.namazu.org/ruby-bsearch/>))

satoru@namazu.org
=end
