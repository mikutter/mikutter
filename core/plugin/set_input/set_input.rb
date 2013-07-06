# -*- coding:utf-8 -*-

Plugin.create :set_input do
  settings _('入力') do
    adjustment _('投稿をリトライする回数'), :message_retry_limit, 1, 99
    boolean _('非公式Retweetにin_reply_to_statusを付与する'), :legacy_retweet_act_as_reply
    settings _('短縮URL') do
      boolean _("常にURLを短縮する"), :shrinkurl_always end
    settings _('フッタ') do
      input _('デフォルトで挿入するフッタ'), :footer
      boolean(_('リプライの場合はフッタを付与しない'), :footer_exclude_reply).
        tooltip(_("リプライの時に[試験3日前]とか入ったらアレでしょう。そんなのともおさらばです。"))
      boolean(_('引用(非公式ReTweet)の場合はフッタを付与しない'), :footer_exclude_retweet).
        tooltip(_("関係ないけど、ツールチップってあんまり役に立つこと書いてないし、後ろ見えないし邪魔ですよねぇ")) end end
end
