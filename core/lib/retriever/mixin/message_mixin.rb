# -*- coding: utf-8 -*-

=begin rdoc
Model用のmoduleで、これをincludeするとMessageに必要最低限のメソッドがロードされ、タイムラインなどに表示できるようになる。
=end
module Retriever::Model::MessageMixin
  # Entityのリストを返す。
  # ==== Return
  # Message::Entity
  def links
    []
  end
  alias :entity :links

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

  # この投稿が、 _Service.primary_ にお気に入り登録されているか否かを返す。
  # ==== Return
  # [true] お気に入りに登録している
  # [false] 登録していない
  def favorite?
    false
  end

  # このRetrieverをお気に入りに登録している _Retriever::Model_ を列挙する。
  # ==== Return
  # [Enumerable<Retriever::Model>] お気に入りに登録しているオブジェクト
  def favorited_by
    []
  end

  # この投稿が、 _Service.primary_ でお気に入りの対応状況を取得する。
  # 既にお気に入りに追加されているとしても、Serviceが対応しているならtrueとなる。
  # ==== Return
  # [true] お気に入りに対応している
  # [false] 対応していない
  def favoritable?
    false
  end

  # このRetrieverをReTweetする。
  # ReTweetとは、Retriever自体を添付した、内容が空のRetrieverを作成すること。
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

  # _Service.primary_ で、このインスタンスがReTweetされているか否かを返す
  # ==== Return
  # [true] 既にReTweetしている
  # [false] していない
  def retweeted?
    false
  end

  # このインスタンスのReTweetにあたる _Retriever::Model_ を列挙する。
  # ==== Return
  # [Enumerable<Retriever::Model>] このインスタンスのReTweetにあたるインスタンス
  def retweeted_by
    []
  end

  # _Service.primary_ が、このインスタンスをReTweetすることに対応しているか否かを返す
  # 既にReTweetしている場合は、必ず _true_ を返す。
  # ==== Return
  # [true] ReTweetに対応している
  # [false] していない
  def retweetable?
    false
  end

  # このMessageがリツイートなら、何のリツイートであるかを返す。
  # 返される値の retweet? は常に false になる
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # [Retriever::Model] ReTweet元のMessage
  # [nil] ReTweetではない
  def retweet_source(force_retrieve=nil)
    nil
  end

  def quoting?
    false
  end

  def has_receive_message?
    false
  end

  def to_show
    @to_show ||= self[:description].gsub(/&(gt|lt|quot|amp);/){|m| {'gt' => '>', 'lt' => '<', 'quot' => '"', 'amp' => '&'}[$1] }.freeze
  end

  def to_message
    self
  end
  alias :message :to_message

  def system?
    false
  end

  def modified
    created
  end

  def from_me?
    false
  end

  def to_me?
    true
  end

  def idname
    self[:user] && self[:user].idname
  end

  def repliable?
    false
  end

  def perma_link
    nil
  end

  def receive_user_screen_names
    []
  end
end
