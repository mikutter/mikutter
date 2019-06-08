# -*- coding: utf-8 -*-
require "set"

module Plugin::Achievement; end
class Plugin::Achievement::Achievement
  attr_reader :slug, :plugin

  def initialize(slug, plugin, options)
    type_strict slug => Symbol, plugin => Plugin, options => Hash
    @slug, @plugin, @options = slug, plugin, options
    @events = Set.new
  end

  def hint ; @options[:hint] || "" end
  def description ; @options[:description] || "" end
  def icon ; @options[:icon] end
  def hidden? ; @options[:hidden] end

  # 解除されていれば真
  def took?
    (UserConfig[:achievement_took] || []).include? slug
  end

  # 解除する
  def take!
    unless took?
      @events.each{ |e| plugin.detach(*e) }
      @events.clear
      if @options[:depends] and not @options[:depends].empty?
        unachievements = Plugin.filtering(:unachievements, {}).first.values_at(*@options[:depends]).compact
        if not unachievements.empty?
          on_achievement_took do |ach|
            if unachievements.delete(ach) and unachievements.empty?
              _force_take! end end
          return self end end
      _force_take! end
    self end

  # 依存してる実績の中で、解除されてない最初の一つを返す
  # ==== Args
  # [&filter] 実績フィルタ。この条件にマッチする実績の中から始めのものを返す
  # ==== Return
  # 見つかった実績(Plugin::Achievement::Achievement)
  # 依存している実績がなかった場合や、全て解除済みの場合は self を返す
  def notachieved_parent(&filter)
    filter ||= ->_{true}
    unachievements = Plugin.filtering(:unachievements, {}).first
    if @options[:depends]
      result = @options[:depends].map{ |slug| unachievements[slug] }.compact.select(&filter).first
      if result
        result.notachieved_parent
      else
        self end
    else
      self end end

  def method_missing(method, *args, &block)
    result = plugin.__send__(method, *args, &block)
    case method.to_s
    when /\Aon_?(.*)\Z/
      @events << [$1.to_sym, result]
    when /\Afilter_?(.*)\Z/
      @events << [$1.to_sym, result]
    end
    result
  end

  private

  def _force_take!
    UserConfig[:achievement_took] = (UserConfig[:achievement_took] || []) + [slug]
    Plugin.call(:achievement_took, self) end

end

Plugin.create :achievement do
  # 実績を定義する
  # ==== Args
  # [slug] 実績のスラッグ
  # [options]
  #   :description 実績の説明。解除してから出ないと見れない。
  #   :hint        実績解除のヒント。解除する条件が整っていれば見れる。
  #   :depends     前提とする実績。実績スラッグの配列。
  #   :icon        実績のアイコンを、Photo Modelで
  #   :hidden      隠し実績（ヒントを出さない）の場合真
  defdsl :defachievement do |slug, options, &block|
    type_strict slug => Symbol, options => Hash
    ach = Plugin::Achievement::Achievement.new(slug, self, options)
    unless ach.took?
      ach.filter_unachievements do |achievements|
        achievements[slug] = ach unless ach.took?
        [achievements]
      end
      filter_achievemented do |achievements|
        achievements[slug] = ach if ach.took?
        [achievements]
      end
      ach.instance_eval(&block)
    end
  end

  defactivity "achievement", _("実績")

  defachievement(:register_account,
                 description: _("mikutterにアカウントを登録した"),
                 hidden: true
                 ) do |ach|
    on_world_after_created do |_|
      ach.take!
    end
  end

  defachievement(:open_setting,
                 description: _("設定画面で、mikutterをカスタマイズしましょう。"),
                 hint: _("画面右下にあるレンチのアイコンをクリックしよう"),
                 depends: [:register_account, :tutorial]
                 ) do |ach|
    on_open_setting do ach.take! end
  end

  defachievement(:multipane,
                 description: _("新規ペインを追加コマンドでペインを増やせます"),
                 hint: _("タブを右クリックして、「新規ペインに移動」をクリックしてみよう"),
                 depends: [:register_account, :tutorial]
                 ) do |ach|
    on_gui_pane_join_window do |pane, window|
      if window.children.inject(0){|i,s| i + (s.is_a?(Plugin::GUI::Pane) ? 1 : 0) } >= 2
        ach.take! end end end

  defachievement(:move_pane,
                 description: _("タブを別のペインにドラッグすれば、そのペインに移動できます"),
                 hint: _("二つ以上ペインがある時に、タブを別のペインにドラッグ＆ドロップしてみましょう"),
                 depends: [:multipane]
                 ) do |ach|
    on_after_gui_tab_reordered do |tab|
      ach.take! end

    on_after_gui_tab_reparent do |tab, old_pane, new_pane|
      ach.take! end end

  defachievement(:bugreporter,
                 description: _("クラッシュレポートの報告ありがとうございます"),
                 hidden: true,
                 depends: [:register_account, :tutorial]
                 ) do |ach|
    on_send_bugreport do |report|
      ach.take! end end

  defachievement(:hidden_command,
                 description: "隠しコマンドを入力した",
                 hidden: true,
                 depends: [:tutorial]
                 ) do |ach|
    on_konami_activate do
      ach.take! end end

  Delayer.new do
    unachievements = Plugin.filtering(:unachievements, {}).first.reject{ |k, v| v.hidden? }
    unless unachievements.empty?
      not_achieved =
        if unachievements.has_key?(:tutorial)
          unachievements[:tutorial]
        else
          unachievements.values.sample.notachieved_parent{|a|!a.hidden?}
        end
      unless not_achieved.hidden?
        if Mopt.debug?
          activity :achievement, "#{not_achieved.hint}\n(slug: #{not_achieved.slug})", icon: not_achieved.icon
        else
          activity :achievement, not_achieved.hint, icon: not_achieved.icon end end end end

  on_achievement_took do |achievement|
    activity :achievement, _("実績 %s を達成しました！おめでとう♪") % achievement.slug.to_s, icon: achievement.icon end

end
