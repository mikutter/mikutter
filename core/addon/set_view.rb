# -*- coding: utf-8 -*-

Plugin::create(:set_view) do

  filter_message_background_color do |message, color|
    color = if(message.from_me?)
              UserConfig[:mumble_self_bg]
            elsif(message.to_me?)
              UserConfig[:mumble_reply_bg]
            else
              UserConfig[:mumble_basic_bg] end
    [message, color]
  end

  settings("表示") do
    settings('フォント') do
      fontcolor 'デフォルトのフォント', :mumble_basic_font, :mumble_basic_color
      fontcolor'リプライ元のフォント', :mumble_reply_font, :mumble_reply_color
    end

    settings('背景色') do
      color 'つぶやき', :mumble_basic_bg
      color '自分宛', :mumble_reply_bg
      color '自分のつぶやき', :mumble_self_bg
    end

    settings('Mentions') do
      boolean('リプライを返したつぶやきにはアイコンを表示', :show_replied_icon).
        tooltip("リプライを返したつぶやきのアイコン上に、リプライボタンを隠さずにずっと表示しておきます。")
    end

    settings('Retweets') do
      boolean('リツイートを表示する', :retweeted_by_anyone_show_timeline).
        tooltip("TL上にリツイートを表示します")
      boolean('リツイートされたつぶやきをTL上でageる', :retweeted_by_anyone_age).
        tooltip("つぶやきがリツイートされたら、投稿された時刻にかかわらず一番上に上げます")
      boolean('自分がリツイートしたつぶやきをTL上でageる', :retweeted_by_myself_age).
        tooltip("自分がリツイートしたつぶやきを、TLの一番上に上げます")
    end

    settings('ふぁぼふぁぼ') do
      boolean('ふぁぼられを表示する', :favorited_by_anyone_show_timeline).
        tooltip("ふぁぼられたつぶやきの下に、ふぁぼった人のアイコンを表示します")
      boolean('ふぁぼられをリプライの受信として処理する', :favorited_by_anyone_act_as_reply).
        tooltip("ふぁぼられたつぶやきが、リプライタブに現れるようになります。")
      boolean('ふぁぼられたつぶやきをTL上でageる', :favorited_by_anyone_age).
        tooltip("つぶやきがふぁぼられたら、投稿された時刻にかかわらず一番上に上げます")
      boolean('自分がふぁぼったつぶやきをTL上でageる', :favorited_by_myself_age).
        tooltip("自分がふぁぼったつぶやきを、TLの一番上に上げます")
    end

    settings('短縮URL') do
      boolean('短縮URLを展開して表示', :shrinkurl_expand).
        tooltip("受信したつぶやきに短縮URLが含まれていた場合、それを短縮されていない状態に戻してから表示します。")
    end

    select 'タブの位置', :tab_position, 0 => '上', 1 => '下', 2 => '左', 3 => '右'

    select('URLを開く方法', :url_open_specified_command) do
      option false, "デフォルトブラウザを使う"
      option true do
        input "次のコマンドを使う", :url_open_command
      end
    end

  end
end
