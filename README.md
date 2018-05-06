# Worldon
mikutterでMastodonへ接続するWorldプラグインです。

## インストール方法
以下のコマンドを実行します。

```shell-session
mkdir -p ~/.mikutter/plugin && git clone git://github.com/cobodo/mikutter-worldon ~/.mikutter/plugin/worldon
```

mikutterを起動して「設定＞アカウント情報＞追加」もしくは画面左上のアイコンから「Worldを追加」からWorld追加ウィザードを開き、「Mastodonアカウント(Worldon)」を選択して、指示に従ってください。

WSLなどではリンクからブラウザが開けないと思うので、あらかじめ「設定＞表示＞URLを開く方法」で適当なブラウザを指定しておいてください。

Worldが追加されると、ストリーム受信が始まり、データソースが準備されますので、「設定＞抽出タブ」で適当なタブを追加し、データソースの一覧から、眺めたいタイムラインを選択してください。

投稿欄を右クリックすると、「カスタム投稿」というコマンドがあります。メディア添付時や、公開範囲の変更、ContentWarningの利用時にはこれを使ってください。

## 特徴
### できる🙆
- HTL, FTL, LTL, リストのストリーム受信
- 投稿・返信・ふぁぼ・ブーストの送信
  - world対応かつインスタンス越境可能
  - 投稿時の画像添付・CW入力・公開範囲変更
- URL・ハッシュタグリンク等の機能
- アカウント登録していないインスタンスの公開TL取得
- 引用tootの展開
  - twitterのステータスURLも引用として展開可能
- 返信スレッド表示
- 返信の表示
- 各種汎用イベントの発火
- ミュート設定の反映
- ふぁぼ・ブーストのactivity表示
- 通知サウンド
- [mikutter-subparts-image](https://github.com/moguno/mikutter-subparts-image) による画像表示
- [sub_parts_client](https://github.com/toshia/mikutter-sub-parts-client) によるクライアント表示
- [mikutter_subparts_nsfw](https://github.com/cobodo/mikutter_subparts_nsfw) によるNSFW表示
- カスタム絵文字の表示

### まだできない🙅
- リストの作成・リネーム・削除
  - リストへのメンバーの追加・削除
- 検索

### 現状ではできないもの
- mikutter本体のScore機能の拡充が必要
  - CW時の本文隠し＆表示機構
- twitterプラグインにおけるuser_detail_viewプラグイン相当のものの実装が必要
  - ユーザーのプロフィール表示
    - リストへの追加・削除

