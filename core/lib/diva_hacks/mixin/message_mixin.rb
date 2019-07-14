# -*- coding: utf-8 -*-

=begin rdoc
Model用のmoduleで、これをincludeするとMessageに必要最低限のメソッドがロードされ、タイムラインなどに表示できるようになる。
=end
module Diva::Model::MessageMixin
  extend Gem::Deprecate

  # この投稿がMentionで、自分が誰かに宛てたものであれば真
  # ==== Return
  # [true] 自分のMention
  # [false] 上記以外
  def mentioned_by_me?
    false
  end

  # この投稿を、現在の _Service.primary_ でお気に入りとしてマークする。
  # ==== Args
  # [_fav] bool お気に入り状態。真ならお気に入りにし、偽なら外す
  # ==== Return
  # [Deferred] 成否判定
  def favorite(_fav=true)
    Deferred.new{ true }
  end

  # この投稿が、 _counterpart_ にお気に入り登録されているか否かを返す。
  # ==== Args
  # [counterpart] お気に入りに追加する側のオブジェクト(Worldやユーザ等)。省略した場合は現在選択されているWorld
  # ==== Return
  # [true] お気に入りに登録している
  # [false] 登録していない
  def favorite?(counterpart=nil)
    false
  end

  # このDivaをお気に入りに登録している _Diva::Model_ を列挙する。
  # ==== Return
  # [Enumerable<Diva::Model>] お気に入りに登録しているオブジェクト
  def favorited_by
    []
  end

  # この投稿が、 _Service.primary_ でお気に入りの対応状況を取得する。
  # 既にお気に入りに追加されているとしても、Serviceが対応しているならtrueとなる。
  # ==== Args
  # [counterpart] お気に入りに追加する側のオブジェクト(Worldやユーザ等)。省略した場合は現在選択されているWorld
  # ==== Return
  # [true] お気に入りに対応している
  # [false] 対応していない
  def favoritable?(counterpart=nil)
    false
  end

  # このDivaをReTweetする。
  # ReTweetとは、Diva自体を添付した、内容が空のDivaを作成すること。
  # 基本的にはTwitter用で、他の用途は想定していない。
  # ==== Return
  # [Deferred] 成否判定
  def retweet
    Deferred.new{ true }
  end

  # このインスタンスがReTweetの基準を満たしているか否かを返す。
  # ==== Return
  # [true] このインスタンスはReTweetである
  # [false] ReTweetではない
  def retweet?
    false
  end

  # _counterpart_ で、このインスタンスがReTweetされているか否かを返す
  # ==== Args
  # [counterpart] お気に入りに追加する側のオブジェクト(Worldやユーザ等)。省略した場合は現在選択されているWorld
  # ==== Return
  # [true] 既にReTweetしている
  # [false] していない
  def retweeted?(counterpart=nil)
    false
  end

  # このインスタンスのReTweetにあたる _Diva::Model_ を列挙する。
  # ==== Return
  # [Enumerable<Diva::Model>] このインスタンスのReTweetにあたるインスタンス
  def retweeted_by
    []
  end

  # _counterpart_ が、このインスタンスをReTweetすることに対応しているか否かを返す
  # 既にReTweetしている場合は、必ず _true_ を返す。
  # ==== Args
  # [counterpart] お気に入りに追加する側のオブジェクト(Worldやユーザ等)。省略した場合は現在選択されているWorld
  # ==== Return
  # [true] ReTweetに対応している
  # [false] していない
  def retweetable?(counterpart=nil)
    false
  end

  # このMessageがリツイートなら、何のリツイートであるかを返す。
  # 返される値の retweet? は常に false になる
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # [Diva::Model] ReTweet元のMessage
  # [nil] ReTweetではない
  def retweet_source(force_retrieve=nil)
    nil
  end

  def quoting?
    false
  end

  # 投稿の宛先になっている投稿を再帰的にさかのぼり、それぞれを引数に取って
  # ブロックが呼ばれる。
  # ブロックが渡されていない場合、 _Enumerator_ を返す。
  # _force_retrieve_ は、 Message#receive_message の引数にそのまま渡される
  # ==== Return
  # obj|Enumerator
  def each_ancestor
    Enumerator.new{|y| y << self }
  end

  # 投稿の宛先になっている投稿を再帰的にさかのぼり、それらを配列にして返す。
  # 配列インデックスが大きいものほど、早く投稿された投稿になる。
  # （[0]は[1]へのリプライ）
  def ancestors(force_retrieve=false)
    [self]
  end

  # 投稿の宛先になっている投稿を再帰的にさかのぼり、何にも宛てられていない投稿を返す。
  # つまり、一番祖先を返す。
  def ancestor(force_retrieve=false)
    ancestors(force_retrieve).last
  end

  def has_receive_message?
    false
  end

  def to_show
    @to_show ||= description.gsub(/&(gt|lt|quot|amp);/){|m| {'gt' => '>', 'lt' => '<', 'quot' => '"', 'amp' => '&'}[$1] }.freeze
  end

  def to_message
    self
  end
  alias :message :to_message

  def system?
    false
  end

  def modified
    self[:modified] || created
  end

  def from_me?(counterpart=nil)
    false
  end

  def to_me?(counterpart=nil)
    false
  end

  def idname
    user.idname
  end

  def repliable?(counterpart=nil)
    false
  end

  def perma_link
    nil
  end

  def receive_user_idnames
    []
  end
  alias :receive_user_screen_names :receive_user_idnames
  deprecate :receive_user_screen_names, "receive_user_idnames", 2020, 7
end
