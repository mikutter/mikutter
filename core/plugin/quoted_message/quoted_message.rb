# -*- coding: utf-8 -*-

Plugin.create :quoted_message do
  # このプラグインが提供するデータソースを返す
  # ==== Return
  # Hash データソース
  def datasources
    ds = {nested_quoted_myself: _("ナウい引用(全てのアカウント)".freeze)}
    Service.each do |service|
      ds["nested_quote_quotedby_#{service.user_obj.id}".to_sym] = "@#{service.user_obj.idname}/" + _('ナウい引用'.freeze) end
    ds end

  command(:copy_tweet_url,
          name: _('ツイートのURLをコピー'.freeze),
          condition: Proc.new{ |opt|
            not opt.messages.any?(&:system?)},
          visible: true,
          role: :timeline) do |opt|
    Gtk::Clipboard.copy(opt.messages.map(&:parma_link).join("\n".freeze))
  end

  command(:quoted_tweet,
          name: _('コメント付きリツイート'.freeze),
          condition: Proc.new{ |opt|
            not opt.messages.any?(&:system?)},
          visible: true,
          role: :timeline) do |opt|
    messages = opt.messages.map(&:message)
    opt.widget.create_postbox(to: messages,
                              footer: ' ' + messages.map(&:parma_link).join(' '.freeze),
                              to_display_only: true)
  end

  filter_extract_datasources do |ds|
    [ds.merge(datasources)] end

  # 管理しているデータソースに値を注入する
  on_appear do |ms|
    ms.each do |message|
      quoted_screen_names = Set.new(
        message.entity.select{ |entity| :urls == entity[:slug] }.map{ |entity|
          matched = Message::PermalinkMatcher.match(entity[:expanded_url])
          matched[:screen_name] if matched && matched.names.include?("screen_name".freeze) })
      quoted_services = Service.select{|service| quoted_screen_names.include? service.user_obj.idname }
      unless quoted_services.empty?
        quoted_services.each do |service|
          Plugin.call :extract_receive_message, "nested_quote_quotedby_#{service.user_obj.id}".to_sym, [message] end
        Plugin.call :extract_receive_message, :nested_quoted_myself, [message] end end end
end
