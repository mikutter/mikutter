# -*- coding: utf-8 -*-

Plugin::create(:set_view) do

  UserConfig[:mumble_system_bg] ||= [255*222, 65535, 255*176]

  filter_message_background_color do |message, color|
    if !color
      color = if(message.respond_to?(:selected) && message.selected)
                UserConfig[:mumble_selected_bg]
              elsif(message.message.system?)
                UserConfig[:mumble_system_bg]
              elsif(message.message.from_me?)
                UserConfig[:mumble_self_bg]
              elsif(message.message.to_me?)
                UserConfig[:mumble_reply_bg]
              else
                UserConfig[:mumble_basic_bg] end end
    [message, color]
  end

  filter_subparts_replyviewer_background_color do |message, color|
    [message, color || UserConfig[:replyviewer_background_color]] end

  filter_subparts_quote_background_color do |message, color|
    [message, color || UserConfig[:quote_background_color]] end

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
    settings(_('つぶやき')) do
      settings(_('通常時')) do
        settings(_('フォント')) do
          fontcolor _('デフォルト'), :mumble_basic_font, :mumble_basic_color
          fontcolor _('ヘッダ（左）'), :mumble_basic_left_font, :mumble_basic_left_color
          fontcolor _('ヘッダ（右）'), :mumble_basic_right_font, :mumble_basic_right_color
        end
        color _('背景色'), :mumble_basic_bg
      end

      settings(_('自分宛')) do
        color _('背景色'), :mumble_reply_bg
      end

      settings(_('自分のつぶやき')) do
        color _('背景色'), :mumble_self_bg
      end

      settings(_('システムメッセージ')) do
        color _('背景色'), :mumble_system_bg
      end

      settings('選択中') do
        color _('背景色'), :mumble_selected_bg
      end
    end

    settings(_('背景色')) do
      color _('つぶやき'), :mumble_basic_bg
      color _('自分宛'), :mumble_reply_bg
      color _('自分のつぶやき'), :mumble_self_bg
      color _('システムメッセージ'), :mumble_system_bg
      color _('選択中'), :mumble_selected_bg
      color(_('コメント付きリツイート'), :quote_background_color).
        tooltip(_('コメント付きリツイートをすると、下に囲われて表示されるじゃないですか、あれです'))
    end

    settings(_('リプライ先')) do
      fontcolor _('フォント'), :reply_text_font, :reply_text_color
      color(_('背景色'), :replyviewer_background_color)

      multiselect _('表示項目'), :reply_present_policy do
        option(:header, _('ヘッダを表示する'))
        option(:icon, _('アイコンを表示する')) do
          select _('アイコンのサイズ'), :reply_icon_size do
            [12,16,24,32,36,48,UserConfig[:reply_icon_size]].compact.uniq.sort.each do |size|
              option size, "#{size}px" if size end end end
        option(:edge, _('枠線を表示する')) do
          select _('枠線の種類'), :reply_edge, floating: _('影'), solid: _('線'), flat: _('枠線なし') end end

      adjustment _('本文の最大行数'), :reply_text_max_line_count, 1, 10
    end

    settings(_('コメント付きリツイート')) do
      fontcolor _('フォント'), :quote_text_font, :quote_text_color
      color(_('背景色'), :quote_background_color)

      multiselect _('表示項目'), :quote_present_policy do
        option(:header, _('ヘッダを表示する'))
        option(:icon, _('アイコンを表示する')) do
          select _('アイコンのサイズ'), :quote_icon_size do
            [12,16,24,32,36,48,UserConfig[:quote_icon_size]].compact.uniq.sort.each do |size|
              option size, "#{size}px" if size end end end
        option(:edge, _('枠線を表示する')) do
          select _('枠線の種類'), :quote_edge, floating: _('影'), solid: _('線'), flat: _('枠線なし') end end

      adjustment _('本文の最大行数'), :quote_text_max_line_count, 1, 10
    end

    settings(_('Mentions')) do
      boolean(_('リプライを返したつぶやきにはアイコンを表示'), :show_replied_icon).
        tooltip(_("リプライを返したつぶやきのアイコン上に、リプライボタンを隠さずにずっと表示しておきます。"))
    end

    settings(_('ふぁぼふぁぼ')) do
      boolean(_('ふぁぼられをリプライの受信として処理する'), :favorited_by_anyone_act_as_reply).
        tooltip(_("ふぁぼられたつぶやきが、リプライタブに現れるようになります。"))
      boolean(_('ふぁぼられたつぶやきをTL上でageる'), :favorited_by_anyone_age).
        tooltip(_("つぶやきがふぁぼられたら、投稿された時刻にかかわらず一番上に上げます"))
      boolean(_('自分がふぁぼったつぶやきをTL上でageる'), :favorited_by_myself_age).
        tooltip(_("自分がふぁぼったつぶやきを、TLの一番上に上げます"))
    end

    settings(_('Retweets')) do
      boolean(_('リツイートされたつぶやきをTL上でageる'), :retweeted_by_anyone_age).
        tooltip(_("つぶやきがリツイートされたら、投稿された時刻にかかわらず一番上に上げます"))
      boolean(_('自分がリツイートしたつぶやきをTL上でageる'), :retweeted_by_myself_age).
        tooltip(_("自分がリツイートしたつぶやきを、TLの一番上に上げます"))
    end

    settings(_('非公開アカウント')) do
      boolean(_('非公開アカウントのつぶやきにはアイコンを表示'), :show_protected_icon).
        tooltip(_("非公開アカウントのつぶやきのアイコン上に、リツイートできないこと示すアイコンを隠さずにずっと表示しておきます。"))
    end

    settings(_('承認済みアカウント')) do
      boolean(_('承認済みアカウントのつぶやきにはアイコンを表示'), :show_verified_icon).
        tooltip(_("Twitterから承認されたアカウントのつぶやきのアイコンの上に、そのことを示すアイコンを隠さずにずっと表示しておきます。"))
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
