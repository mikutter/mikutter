# -*- coding: utf-8 -*-

Plugin::create(:set_view) do

  UserConfig[:mumble_system_bg] ||= [255*222, 65535, 255*176]

  filter_message_background_color do |message, color|
    if !color
      color = if(message.selected)
                UserConfig[:mumble_selected_bg]
              elsif(message.to_message.system?)
                UserConfig[:mumble_system_bg]
              elsif(message.to_message.from_me?)
                UserConfig[:mumble_self_bg]
              elsif(message.to_message.to_me?)
                UserConfig[:mumble_reply_bg]
              else
                UserConfig[:mumble_basic_bg] end end
    [message, color]
  end

  filter_message_font do |message, font|
    [message, font || UserConfig[:mumble_basic_font]] end

  filter_message_font_color do |message, color|
    [message, color || UserConfig[:mumble_basic_color]] end

  filter_message_header_left_font do |message, font|
    [message, font || UserConfig[:mumble_basic_left_font]] end

  filter_message_header_left_font_color do |message, color|
    [message, color || UserConfig[:mumble_basic_left_color]] end

  filter_message_header_right_font do |message, font|
    [message, font || UserConfig[:mumble_basic_right_font]] end

  filter_message_header_right_font_color do |message, color|
    [message, color || UserConfig[:mumble_basic_right_color]] end

  settings(_("表示")) do
    settings(_('フォント')) do
      fontcolor _('デフォルト'), :mumble_basic_font, :mumble_basic_color
      fontcolor _('リプライ元'), :mumble_reply_font, :mumble_reply_color
      fontcolor _('ヘッダ（左）'), :mumble_basic_left_font, :mumble_basic_left_color
      fontcolor _('ヘッダ（右）'), :mumble_basic_right_font, :mumble_basic_right_color
    end

    settings(_('背景色')) do
      color _('つぶやき'), :mumble_basic_bg
      color _('自分宛'), :mumble_reply_bg
      color _('自分のつぶやき'), :mumble_self_bg
      color _('システムメッセージ'), :mumble_system_bg
      color _('選択中'), :mumble_selected_bg
    end

    settings(_('Mentions')) do
      boolean(_('リプライを返したつぶやきにはアイコンを表示'), :show_replied_icon).
        tooltip(_("リプライを返したつぶやきのアイコン上に、リプライボタンを隠さずにずっと表示しておきます。"))
    end

    settings(_('Retweets')) do
      boolean(_('リツイートされたつぶやきをTL上でageる'), :retweeted_by_anyone_age).
        tooltip(_("つぶやきがリツイートされたら、投稿された時刻にかかわらず一番上に上げます"))
      boolean(_('自分がリツイートしたつぶやきをTL上でageる'), :retweeted_by_myself_age).
        tooltip(_("自分がリツイートしたつぶやきを、TLの一番上に上げます"))
    end

    settings(_('ふぁぼふぁぼ')) do
      boolean(_('ふぁぼられをリプライの受信として処理する'), :favorited_by_anyone_act_as_reply).
        tooltip(_("ふぁぼられたつぶやきが、リプライタブに現れるようになります。"))
      boolean(_('ふぁぼられたつぶやきをTL上でageる'), :favorited_by_anyone_age).
        tooltip(_("つぶやきがふぁぼられたら、投稿された時刻にかかわらず一番上に上げます"))
      boolean(_('自分がふぁぼったつぶやきをTL上でageる'), :favorited_by_myself_age).
        tooltip(_("自分がふぁぼったつぶやきを、TLの一番上に上げます"))
    end

    settings(_('短縮URL')) do
      boolean(_('短縮URLを展開して表示'), :shrinkurl_expand).
        tooltip(_("受信したつぶやきに短縮URLが含まれていた場合、それを短縮されていない状態に戻してから表示します。"))
    end

    select _('タブの位置'), :tab_position, 0 => _('上'), 1 => _('下'), 2 => _('左'), 3 => _('右')

    select(_('URLを開く方法'), :url_open_specified_command) do
      option false, _("デフォルトブラウザを使う")
      option true do
        input _("次のコマンドを使う"), :url_open_command
      end
    end

  end
end
