# -*- coding: utf-8 -*-

Plugin::create(:basic_settings) do
  settings(_('基本設定')) do
    boolean _('リプライ元をサーバに問い合わせて取得する'), :retrieve_force_mumbleparent

    about (_("%s について") % Environment::NAME), {
      :name => Environment::NAME,
      :version => Environment::VERSION.to_s,
      :copyright => _('2009-%s Toshiaki Asai') % '2021',
      :comments => _("全てのミク廃、そしてマイクロブログ中毒者へ贈る、至高のMastodonクライアントを目指すMastodonクライアント。\n略して至高のMastodonクライアント。\n圧倒的なかわいさではないか我がミクは\n\nこのソフトウェアは %{license} によって浄化されています。") % {license: 'MIT License'},
      :license => (file_get_contents('../LICENSE') rescue nil),
      :website => _('https://mikutter.hachune.net/'),
      :logo => Skin.photo('icon.png'),
      :authors => %w[
        @toshi_a@social.mikutter.hachune.net
        Phenomer
        @osa_k@social.mikutter.hachune.net
        katsyoshi
        @ahiru@social.mikutter.hachune.net
        @cobodo@mstdn.kanagu.info
        @shibafu528@social.mikutter.hachune.net
        @yuntan_t@mstdn.maud.io
      ],
      :artists => ['toshi_a', 'soramame_bscl', 'seibe2'],
      :documenters => ['toshi_a']
    }

  end
end
