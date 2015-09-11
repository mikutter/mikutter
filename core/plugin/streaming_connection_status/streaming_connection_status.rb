# -*- coding: utf-8 -*-

Plugin.create(:streaming_connection_status) do
  defactivity 'streaming_status', _('Streaming APIの接続状況')

  on_streaming_connection_status_connected do |streaming_kind, last_response_code|
    if last_response_code == '200'.freeze
      activity("ratelimit", _('%{streaming_kind}: 接続しました。'.freeze) % {streaming_kind: streaming_kind})
    else
      desc = [_('%{streaming_kind}: 接続できました。'.freeze) % {streaming_kind: streaming_kind}]
      if last_response_code.start_with?('5'.freeze)
        desc << _("まだTwitterサーバが完全には復旧していないかも知れません。\nTwitterサーバの情報は以下のWebページで確認することができます。\n%{twitter_status_url}".freeze) % {twitter_status_url: 'https://dev.twitter.com/status'.freeze}
      elsif last_response_code == '420'.freeze
        desc << _('規制解除されたみたいですね。よかったですね'.freeze) end
      activity(:ratelimit, desc.first,
               description: desc.join("\n".freeze)) end
  end

  on_streaming_connection_status_failed do |streaming_kind, error_string|
    title = _("%{streaming_kind}: 切断されました。再接続します".freeze) % {streaming_kind: streaming_kind}
    activity(:ratelimit, title,
             description: _("%{title}\n接続できませんでした(%{error_string})".freeze) % {
               error_string: get_error_str(e),
               title: title })
  end

  on_streaming_connection_status_ratelimit do |streaming_kind, error_string|
    title = _("%{streaming_kind}: API実行回数制限を超えました。しばらくしてから自動的に再接続します。".freeze) % {streaming_kind: streaming_kind}
    activity(:ratelimit, title,
             description: _("%{title}\n(%{error_string})".freeze) % {
               error_string: error_string,
               title: title })
  end

  on_streaming_connection_status_flying_whale do |streaming_kind, error_string|
    title = _("%{streaming_kind}: 切断されました。しばらくしてから自動的に再接続します。".freeze) % {streaming_kind: streaming_kind}
    activity(:ratelimit, title,
             description: _("%{title}\nTwitterサーバが応答しません。また何かあったのでしょう(%{error_string})。\nTwitterサーバの情報は以下のWebページで確認することができます。\n%{twitter_status_url}".freeze) % {
               twitter_status_url: 'https://dev.twitter.com/status'.freeze,
               error_string: error_string,
               title: title })
  end
end
