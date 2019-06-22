HOW TO BUILD MIKUTTER APPIMAGE
==============================
Using Docker
------------
### PREREQUISITE
Docker

### USAGE
```bash
docker build -t mikutter-build-appimage . && docker run -e REVISION=3.6.0 -v $PWD/volume:/volume -it mikutter-build-appimage
```

環境変数 `REVISION` にはGitのタグ名やブランチ名を入れる．
ビルドに成功すると`./volume`以下に`mikutter-*.AppImage`が生成されているはず．確認したら`docker rm`でコンテナを破棄する．
