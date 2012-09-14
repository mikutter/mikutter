# -*- coding: utf-8 -*-

module Plugin::GUI::TabLike

  attr_reader :icon
  attr_accessor :deletable

  def initialize(*args)
    @expand = true
    super
  end

  # できるだけ小さく表示する
  # ==== Return
  # self
  def shrink
    @expand = false
    self end

  # できるだけ大きく表示する
  # ==== Return
  # self
  def expand(new = true)
    @expand = new
    self end

  def expand?
    @expand end

  def pack_rule
    @pack_rule ||= [] end

  # タイムラインを作成してこの中に入れる
  # ==== Args
  # [slug] タイムラインスラッグ
  # [&proc] 処理
  # ==== Return
  # 新しく作成したタイムライン
  def timeline(slug, &proc)
    timeline = Plugin::GUI::Timeline.instance(slug)
    self << timeline
    pack_rule.push(expand?)
    timeline.instance_eval &proc if proc
    timeline end

  # プロフィールを作成してこの中に入れる
  # ==== Args
  # [slug] プロフィールスラッグ
  # [&proc] 処理
  # ==== Return
  # 新しく作成したプロフィール
  def profile(slug, &proc)
    profile = Plugin::GUI::Profile.instance(slug)
    self << profile
    pack_rule.push(expand?)
    notice "pack_rule: #{pack_rule.inspect}"
    profile.instance_eval &proc if proc
    profile end

  # UIツールキットのウィジェット(Gtk等)をタブに入れる
  # ==== Args
  # [widget] ウィジェット
  # ==== Return
  # self
  def nativewidget(widget)
    Plugin.call("gui_nativewidget_join_#{self.class.role}".to_sym, self, widget)
    pack_rule.push(expand?)
    self end

  def set_icon(new)
    if @icon != new
      @icon = new
      Plugin.call(:gui_tab_change_icon, self) end
    self end

  def set_deletable(new)
    @deletable = new
    self end

end
