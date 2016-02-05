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

  def add_child(child, *args)
    result = super(child, *args)
    pack_rule[children.index(child)] = expand?
    result end
  alias << add_child

  # タイムラインを作成してこの中に入れる
  # ==== Args
  # [slug] タイムラインスラッグ
  # [&proc] 処理
  # ==== Return
  # 新しく作成したタイムライン
  def timeline(slug, &proc)
    timeline = Plugin::GUI::Timeline.instance(slug)
    self << timeline
    timeline.instance_eval(&proc) if proc
    timeline end

  # プロフィールを作成してこの中に入れる
  # ==== Args
  # [slug] プロフィールスラッグ
  # [&proc] 処理
  # ==== Return
  # 新しく作成したプロフィール
  def cluster(slug, &proc)
    cluster = Plugin::GUI::Cluster.instance(slug)
    self << cluster
    pack_rule.push(expand?)
    cluster.instance_eval(&proc) if proc
    cluster end

  # UIツールキットのウィジェット(Gtk等)をタブに入れる
  # ==== Args
  # [widget] ウィジェット
  # ==== Return
  # self
  def nativewidget(widget)
    i_container = Plugin::GUI::TabChildWidget.instance
    self << i_container
    Plugin.call("gui_nativewidget_join_#{self.class.role}".to_sym, self, i_container, widget)
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

  def name=(new_name)
    result = super new_name
    Plugin.call(:gui_tab_change_icon, self)
    result end

end
