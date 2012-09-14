# -*- coding:utf-8 -*-

Plugin.create :set_input do
  settings '入力' do
    adjustment '投稿をリトライする回数', :message_retry_limit, 1, 99
    boolean '非公式Retweetにin_reply_to_statusを付与する', :legacy_retweet_act_as_reply
    settings '短縮URL' do
      boolean "常にURLを短縮する", :shrinkurl_always end
    settings 'フッタ' do
      input 'デフォルトで挿入するフッタ', :footer
      boolean('リプライの場合はフッタを付与しない', :footer_exclude_reply).
        tooltip("リプライの時に[試験3日前]とか入ったらアレでしょう。そんなのともおさらばです。")
      boolean('引用(非公式ReTweet)の場合はフッタを付与しない', :footer_exclude_retweet).
        tooltip("関係ないけど、ツールチップってあんまり役に立つこと書いてないし、後ろ見えないし邪魔ですよねぇ") end end
end
