# -*- coding: utf-8 -*-

Plugin::create(:basic_settings) do
  settings(_ '基本設定') do
    settings(_ '各情報を取りに行く間隔。単位は分') do
      adjustment(_('タイムラインとリプライ'), :retrieve_interval_friendtl, 1, 60*24).
        tooltip(_ 'あなたがフォローしている人からのリプライとつぶやきの取得間隔')

      adjustment(_('フォローしていない人からのリプライ'),:retrieve_interval_mention, 1, 60*24).
        tooltip(_("あなたに送られてきたリプライを取得する間隔。\n上との違いは、あなたがフォローしていない人からのリプライも取得出来ることです"))

      adjustment(_('保存した検索'), :retrieve_interval_search, 1, 60*24).
        tooltip(_ '保存した検索を確認しに行く間隔')

      adjustment(_('リストのタイムライン'), :retrieve_interval_list_timeline, 1, 60*24).
        tooltip(_ '表示中のリストのタイムラインを確認しに行く間隔')

      adjustment(_('フォロー'), :retrieve_interval_followings, 1, 60*24).
        tooltip(_ 'フォロー一覧を確認しに行く間隔。mikutterを使わずにフォローした場合、この時に同期される')

      adjustment(_('フォロワー'), :retrieve_interval_followers, 1, 60*24).
        tooltip(_ 'フォロワー一覧を確認しに行く間隔')

      adjustment(_('ダイレクトメッセージ'), :retrieve_interval_direct_messages, 1, 60*24).
        tooltip(_ 'ダイレクトメッセージを確認しに行く間隔')
    end

    settings(_ '一度に取得するつぶやきの件数(1-200)') do
      adjustment(_('タイムラインとリプライ'), :retrieve_count_friendtl, 1, 200)
      adjustment(_('フォローしていない人からのリプライ'), :retrieve_count_mention, 1, 200)
      adjustment(_('フォロー'), :retrieve_count_followings, 1, 100000)
      adjustment(_('フォロワー'), :retrieve_count_followers, 1, 100000)
      adjustment(_('ダイレクトメッセージ'), :retrieve_count_direct_messages, 1, 200)
    end

    settings(_ 'イベントの発生頻度(ミリ秒単位)') do
      adjustment(_('タイムラインとリプライとリツイート'), :update_queue_delay, 100, 10000)
      adjustment(_('ふぁぼられ'), :favorite_queue_delay, 100, 10000)
      adjustment(_('フォロワー'), :follow_queue_delay, 100, 10000)
      adjustment(_('ダイレクトメッセージ'), :direct_message_queue_delay, 100, 10000)
    end

    settings _('リアルタイム更新') do
      boolean(_('ホームタイムライン(UserStream)'), :realtime_rewind).
        tooltip _('Twitter の UserStream APIを用いて、リアルタイムにツイートやフォローなどのイベントを受け取ります')
      boolean(_('リスト(Streaming API)'), :filter_realtime_rewind).
        tooltip _('Twitter の Streaming APIを用いて、リアルタイムにリストの更新等を受け取ります')
    end

    boolean _('リプライ元をサーバに問い合わせて取得する'), :retrieve_force_mumbleparent
    boolean(_('つぶやきの取得漏れを防止する（遅延対策）'), :anti_retrieve_fail).
      tooltip _('遅延に強くなりますが、ちょっと遅くなります。')

    about (_("%s について") % Environment::NAME), {
      :name => Environment::NAME,
      :version => Environment::VERSION.to_s,
      :copyright => _('2009-%s Toshiaki Asai') % 2013,
      :comments => _("全てのミク廃、そしてTwitter中毒者へ贈る、至高のTwitter Clientを目指すTwitter Client。\n略して至高のTwitter Client。\n圧倒的なかわいさではないか我がミクは\n\nこのソフトウェアは GPL3 によって浄化されています。"),
      :license => (file_get_contents('../LICENSE') rescue nil),
      :website => _('http://mikutter.hachune.net/'),
      :logo => Skin.get('icon.png'),
      :authors => ['toshi_a', 'Phenomer'],
      :artists => ['toshi_a', 'soramame_bscl', 'seibe2'],
      :documenters => ['toshi_a']
    }

  end
end
