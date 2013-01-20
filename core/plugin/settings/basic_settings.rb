# -*- coding: utf-8 -*-

Plugin::create(:basic_settings) do
  settings('基本設定') do
    settings('各情報を取りに行く間隔。単位は分') do
      adjustment('タイムラインとリプライ', :retrieve_interval_friendtl, 1, 60*24).
        tooltip('あなたがフォローしている人からのリプライとつぶやきの取得間隔')

      adjustment('フォローしていない人からのリプライ',:retrieve_interval_mention, 1, 60*24).
        tooltip("あなたに送られてきたリプライを取得する間隔。\n"+
                "上との違いは、あなたがフォローしていない人からのリプライも取得出来ることです")

      adjustment('保存した検索', :retrieve_interval_search, 1, 60*24).
        tooltip('保存した検索を確認しに行く間隔')

      adjustment('リストのタイムライン', :retrieve_interval_list_timeline, 1, 60*24).
        tooltip('表示中のリストのタイムラインを確認しに行く間隔')

      adjustment('フォロー', :retrieve_interval_followings, 1, 60*24).
        tooltip('フォロー一覧を確認しに行く間隔。mikutterを使わずにフォローした場合、この時に同期される')

      adjustment('フォロワー', :retrieve_interval_followers, 1, 60*24).
        tooltip('フォロワー一覧を確認しに行く間隔')

      adjustment('ダイレクトメッセージ', :retrieve_interval_direct_messages, 1, 60*24).
        tooltip('ダイレクトメッセージを確認しに行く間隔')
    end

    settings('一度に取得するつぶやきの件数(1-200)') do
      adjustment('タイムラインとリプライ', :retrieve_count_friendtl, 1, 200)
      adjustment('フォローしていない人からのリプライ', :retrieve_count_mention, 1, 200)
      adjustment('フォロー', :retrieve_count_followings, 1, 100000)
      adjustment('フォロワー', :retrieve_count_followers, 1, 100000)
      adjustment('ダイレクトメッセージ', :retrieve_count_direct_messages, 1, 200)
    end

    settings('イベントの発生頻度(ミリ秒単位)') do
      adjustment('タイムラインとリプライとリツイート', :update_queue_delay, 100, 10000)
      adjustment('ふぁぼられ', :favorite_queue_delay, 100, 10000)
      adjustment('フォロワー', :follow_queue_delay, 100, 10000)
      adjustment('ダイレクトメッセージ', :direct_message_queue_delay, 100, 10000)
    end

    settings 'リアルタイム更新' do
      boolean('ホームタイムライン(UserStream)', :realtime_rewind).
        tooltip 'Twitter の UserStream APIを用いて、リアルタイムにツイートやフォローなどのイベントを受け取ります'
      boolean('リスト(Streaming API)', :filter_realtime_rewind).
        tooltip 'Twitter の Streaming APIを用いて、リアルタイムにリストの更新等を受け取ります'
    end

    boolean 'リプライ元をサーバに問い合わせて取得する', :retrieve_force_mumbleparent
    boolean('つぶやきの取得漏れを防止する（遅延対策）', :anti_retrieve_fail).
      tooltip '遅延に強くなりますが、ちょっと遅くなります。'

    about "#{Environment::NAME} について", {
      :name => Environment::NAME,
      :version => Environment::VERSION.to_s,
      :copyright => '2009-2013 Toshiaki Asai',
      :comments => "全てのミク廃、そしてTwitter中毒者へ贈る、至高のTwitter Clientを目指すTwitter Client。
略して至高のTwitter Client。
圧倒的なかわいさではないか我がミクは

このソフトウェアは GPL3 によって浄化されています。",
      :license => (file_get_contents('../LICENSE') rescue nil),
      :website => 'http://mikutter.hachune.net/',
      :logo => Skin.get('icon.png'),
      :authors => ['toshi_a', 'Phenomer', 'tana_ash'],
      :artists => ['toshi_a', 'soramame_bscl', 'bina1204', 'seibe2'],
      :documenters => ['toshi_a']
    }

  end
end
