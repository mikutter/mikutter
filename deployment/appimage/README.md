HOW TO BUILD MIKUTTER APPIMAGE
==============================
Using Vagrant
-------------
### PREREQUISITE
Vagrant, VirtualBox

### USAGE
```bash
REVISION=3.6.0 vagrant up
```

環境変数 `REVISION` にはGitのタグ名やブランチ名を入れる．`REVISION`を指定しなかった場合`master`が使用される．数分待つと `mikutter-*.AppImage` が手元に生成されているはず．それを確認したら `vagrant destroy` して，ビルドに用いたVMを破棄する．

もしビルドに失敗したら `vagrant ssh` でVMに入って状況を確認する．

Using Docker
------------
### PREREQUISITE
Docker

### USAGE
```bash
sudo docker build -t mikutter . && sudo docker run -e REVISION=3.6.0 -v $PWD/volume:/volume -it mikutter
```

ビルドに成功すると`./volume`以下に`mikutter-*.AppImage`が生成されているはず．確認したら`docker rm`でコンテナを破棄する．
