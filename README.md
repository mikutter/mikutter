# Worldon
mikutterでMastodonへ接続するWorldプラグインです。

まだほとんどの機能がなく、非常にbuggyです。mikutterでMastodonを使用する場合は https://github.com/sora0920/mikutodon がオススメです。

## 特徴
### できる🙆
- HTL, FTL, LTL, リストのストリーム受信
- 投稿・ふぁぼ・ブーストの送信（world対応かつインスタンス越境可能）
- URL・ハッシュタグリンク等の機能

### まだできない🙅
- 返信
- 通知
- 画像添付
- カスタム絵文字表示
- 各種汎用イベントの発火

### クソ💩
- 同期処理多すぎ

## インストール方法
```shell-session
mkdir -p ~/.mikutter/plugin
git clone github.com:cobodo/mikutter-worldon ~/.mikutter/plugin/worldon
cd /path/to/mikutter
bundle install
```

