# -*- coding: utf-8 -*-
require_relative 'error'
require_relative 'keep'
require_relative 'service'

miquire :core, 'environment', 'configloader', 'userconfig'
miquire :lib, 'diva_hacks'

Plugin.create(:account) do

  # 登録済みアカウントを全て取得するのに使うフィルタ。
  # 登録されているAccountに対応するModelをyielderに格納する。
  filter_accounts do |yielder|
    accounts.each do |account|
      yielder << account
    end
    [yielder]
  end

  # 現在選択されているアカウントに対応するModelを返すフィルタ。
  filter_account_current do |result|
    if result
      [result]
    else
      [current_account]
    end
  end

  # カレントアカウントを _new_ に変更する
  on_account_change_current do |new|
    begin
      if self.current_account != new
        self.current_account = new
        Plugin.call(:primary_service_changed, current_account)
      end
    rescue Plugin::Account::InvalidAccountError => err
      error err
    end
  end

  # 新たなアカウント _new_ を追加する
  on_account_add do |new|
    register_account(new)
  end

  # 新たなアカウント _new_ を追加する
  on_account_destroy do |target|
    destroy_account(target)
  end

  # Account Modelについて繰り返すArrayを返す。
  # 各要素は、アカウントの順番通りに格納されている。
  # 外部からこのメソッド相当のことをする場合は、 _accounts_ フィルタを利用すること。
  # ==== Return
  # [Array] アカウントModelを格納したArray
  def accounts
    @accounts ||= Plugin::Account::Keep.accounts.map do |id, serialized|
      provider = Diva::Model(serialized[:provider])
      if provider
        provider.new(serialized)
      else
        raise "unknown model #{serialized[:provider].inspect}"
      end
    end
  end

  # 現在選択されているアカウントを返す
  # ==== Return
  # [Diva::Model] カレントアカウント
  def current_account
    @current || self.current_account = accounts.first
  end

  # カレントアカウントを _new_ に変更する。
  # ==== Args
  # [new]
  #   新たなカレントアカウント(Diva::Model)。
  #   _accounts_ が返す内容のうちのいずれかでなければならない。
  # ==== Return
  # [Diva::Model] 新たなカレントアカウント
  # ==== Raise
  # [Plugin::Account::InvalidAccountError] _accounts_ にないアカウントが渡された場合
  def current_account=(new)
    raise Plugin::Account::InvalidAccountError unless accounts.include?(new)
    @current = new
  end

  # 新たなアカウントを登録する。
  # ==== Args
  # [new] 追加するアカウント(Diva::Model)
  def register_account(new)
    fail "TODO: 実装する"
  end

  def destroy_account(target)
    Service::SaveData.account_destroy target.name
    Plugin.call(:service_destroyed, target)
  end

end
