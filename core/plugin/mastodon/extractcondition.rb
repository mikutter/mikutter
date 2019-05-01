Plugin.create(:mastodon) do
  cl = Plugin::Mastodon::Status

  defextractcondition(:mastodon_status, name: "Mastodonで受信したトゥート", operator: false, args: 0) do |message: raise|
    message.is_a?(cl)
  end
  defextractcondition(:mastodon_domain, name: "ドメイン(Mastodon)", operator: true, args: 1, sexp: MIKU.parse("`(,compare (host (uri message)) ,(car args))"))
  defextractcondition(:mastodon_spoiler_text, name: "CWテキスト(Mastodon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.spoiler_text, arg)
  end
  defextractcondition(:mastodon_visibility, name: "公開範囲(Mastodon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.visibility, arg)
  end
  defextractcondition(:mastodon_include_emoji, name: "カスタム絵文字を含む(Mastodon)", operator: false, args: 0) do |message: raise|
    message.is_a?(cl) && message.emojis.to_a.any?
  end
  defextractcondition(:mastodon_emoji, name: "カスタム絵文字(Mastodon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.emojis.to_a.map{|emoji| emoji.shortcode }.join(' '), arg)
  end
  defextractcondition(:mastodon_tag, name: "ハッシュタグ(Mastodon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.tags.to_a.map{|tag| tag.name }.join(' '), arg.downcase)
  end
  defextractcondition(:mastodon_bio, name: "プロフィール(Mastodon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.account.note, arg)
  end
end
