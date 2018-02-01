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
- 引用・返信のタグ除去
- 添付画像の処理
- 通知
- 投稿時の画像添付・CW入力・公開範囲変更
- トゥートの削除
- CW時の本文隠し＆表示機構
- カスタム絵文字表示
- ユーザーのプロフィール表示
- アカウント登録していないインスタンスの公開TL取得

### クソ💩
- 同期処理多すぎ

## インストール方法
以下のコマンドを実行します。

```shell-session
mkdir -p ~/.mikutter/plugin
git clone github.com:cobodo/mikutter-worldon ~/.mikutter/plugin/worldon
cd /path/to/mikutter
bundle install
```

mikutterを起動して「設定＞アカウント情報＞追加」もしくは画面左上のアイコンから「Worldを追加」からWorld追加ウィザードを開き、「Mastodonアカウント(Worldon)」を選択して、指示に従ってください。

WSLなどではリンクからブラウザが開けないと思うので、あらかじめ「設定＞表示＞URLを開く方法」で適当なブラウザを指定しておいてください。

Worldが追加されると、ストリーム受信が始まり、データソースが準備されますので、「設定＞抽出タブ」で適当なタブを追加し、データソースの一覧から、眺めたいタイムラインを選択してください。

