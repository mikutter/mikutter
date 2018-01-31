# Worldon
mikutterでMastodonへ接続するWorldプラグインです。

まだほとんどの機能がなく、非常にbuggyです。mikutterでMastodonを使用する場合は https://github.com/sora0920/mikutodon がオススメです。

## 特徴
### できる🙆
- HTL, FTL, LTL, リストのストリーム受信
- 投稿・返信・ふぁぼ・ブーストの送信（world対応かつインスタンス越境可能）
- URL・ハッシュタグリンク等の機能
- 引用tootの展開（暫定）
- 返信スレッド表示
- 返信の表示
- 各種汎用イベントの発火
- ミュート設定の反映

### まだできない🙅
- 引用・返信のアイコン表示・タグ除去
- 添付画像の処理
- 通知
- 投稿時の画像添付・CW入力・公開範囲変更
- CW時の本文隠し＆表示機構
- カスタム絵文字表示
- ユーザーのプロフィール表示
- アカウント登録していないインスタンスの公開TL取得

### クソ💩
- 同期処理多すぎ

## インストール方法
```shell-session
mkdir -p ~/.mikutter/plugin
git clone github.com:cobodo/mikutter-worldon ~/.mikutter/plugin/worldon
cd /path/to/mikutter
bundle install
```

