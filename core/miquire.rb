# -*- coding: utf-8 -*-
# 多くの人に最初に突っ込まれるメソッドが定義されておったのじゃ

$LOAD_PATH.
  unshift(File.expand_path(__dir__))

# ミクってかわいいよねぇ。
# ツインテールいいよねー。
# どう良いのかを書くとコードより長くなりそうだから詳しくは書かないけどいいよねぇ。
# ふたりで寒い時とかに歩いてたら首にまいてくれるんだよー。
# 我ながらなんてわかりやすい説明なんだろう。
module Miquire
  class LoadError < StandardError; end
end
