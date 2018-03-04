Plugin.create(:worldon) do
  cl = Plugin::Worldon::Status

  defextractcondition(:worldon_domain, name: "ドメイン(Worldon)", operator: true, args: 1, sexp: MIKU.parse("`(,compare (host (uri message)) ,(car args))"))
  defextractcondition(:worldon_spoiler_text, name: "CWテキスト(Worldon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.spoiler_text, arg)
  end
  defextractcondition(:worldon_visibility, name: "公開範囲(Worldon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.visibility, arg)
  end
  defextractcondition(:worldon_include_emoji, name: "カスタム絵文字を含む(Worldon)", operator: false, args: 0) do |message: raise|
    message.is_a?(cl) && message.emojis.to_a.any?
  end
  defextractcondition(:worldon_emoji, name: "カスタム絵文字(Worldon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.emojis.to_a.map{|emoji| emoji.shortcode }.join(' '), arg)
  end
  defextractcondition(:worldon_tag, name: "ハッシュタグ(Worldon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.tags.to_a.map{|tag| tag.name }.join(' '), arg.downcase)
  end
  defextractcondition(:worldon_bio, name: "プロフィール(Worldon)", operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.is_a?(cl) && compare.(message.account.note, arg)
  end
end
