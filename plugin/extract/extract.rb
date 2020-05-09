# -*- coding: utf-8 -*-

require_relative 'edit_window'
require_relative 'extract_tab_list'
require_relative 'model/setting'

module Plugin::Extract
  class ConditionNotFoundError < RuntimeError; end

  ExtensibleCondition = Struct.new(:slug, :name, :operator, :args) do
    def initialize(*_args, &block)
      super
      @block = block end

    def to_proc
      @block end

    def call(*_args, **_named, &block)
      @block.(*_args, **_named, &block) end end

  class ExtensibleSexpCondition < ExtensibleCondition
    attr_reader :sexp

    def initialize(*args)
      @sexp = args.pop
      super(*args) end
  end

  ExtensibleOperator = Struct.new(:slug, :name, :args) do
    def initialize(*_args, &block)
      super
      @block = block end

    def to_proc
      @block end

    def call(*_args, **_named, &block)
      @block.(*_args, **_named, &block) end end

  Order = Struct.new(:slug, :name, :ordering)

  class Calc
    def self.inherited(child)
      child.class_eval do
        operators = Plugin.filtering(:extract_operator, Set.new).first
        operators.each { |operator|
          define_method(operator.slug) do |other|
            @condition.(other, message: @message, operator: operator.slug, &operator)
          end
        }
      end
    end

    def initialize(message, condition)
      type_strict condition => Plugin::Extract::ExtensibleCondition
      @message, @condition = message, condition
    end

    def call(*args)
      @condition.(*args, message: @message)
    end
  end
end

Plugin.create :extract do
  # ストリームオブジェクトの集合。
  # ストリームオブジェクトは、以下のようなフィールドを持っている必要がある。
  # field.string :title, required: true           # 画面に表示される、抽出タブの名前
  # field.string :datasource_slug, required: true # データソーススラッグ
  defevent :message_stream, prototype: [Pluggaloid::COLLECT]

  defevent :extract_receive_message, prototype: [Plugin::Extract::Setting, Pluggaloid::STREAM]
  defevent :extract_order, prototype: [Pluggaloid::COLLECT]

  @load_time = Time.new.freeze

  # 抽出タブオブジェクト。各キーは抽出タブslugで、値は以下のようなオブジェクト
  # name :: タブの名前
  # sexp :: 条件式（S式）
  # source :: どこのツイートを見るか（イベント名、配列で複数）
  # slug :: タイムラインとタブのスラッグ
  def extract_tabs
    @extract_tabs ||= {} end

  def message_created_after_load_proc
    @message_created_after_load_proc ||= ->(message) { message.created >= @load_time }
  end

  settings _("抽出タブ") do
    tablist = Plugin::Extract::ExtractTabList.new(Plugin[:extract])
    pack_start(Gtk::HBox.new.
               add(tablist).
               closeup(Gtk::VBox.new(false, 4).
                       closeup(Gtk::Button.new(Gtk::Stock::ADD).tap{ |button|
                                 button.ssc(:clicked) {
                                   Plugin.call :extract_tab_open_create_dialog
                                   true } }).
                       closeup(Gtk::Button.new(Gtk::Stock::EDIT).tap{ |button|
                                 button.ssc(:clicked) {
                                   slug = tablist.selected_slug
                                   if slug
                                     Plugin.call(:extract_open_edit_dialog, slug)
                                   end
                                   true } }).
                       closeup(Gtk::Button.new(Gtk::Stock::DELETE).tap{ |button|
                                 button.ssc(:clicked) {
                                   slug = tablist.selected_slug
                                   if slug
                                     Plugin.call(:extract_tab_delete_with_confirm, slug)
                                   end
                                   true } })))
    add_tab_observer = on_extract_tab_create(&tablist.method(:add_record))
    delete_tab_observer = on_extract_tab_delete(&tablist.method(:remove_record))
    tablist.ssc(:destroy) do
      detach add_tab_observer
      detach delete_tab_observer
    end
  end

  command(:extract_edit,
          name: _('抽出条件を編集'),
          condition: lambda{ |opt|
            extract_tabs.values.any? { |es| es.slug == opt.widget.slug }
          },
          visible: true,
          role: :tab) do |opt|
    extract = extract_tabs.values.find { |es| es.slug == opt.widget.slug }
    Plugin.call(:extract_open_edit_dialog, extract.slug) if extract
  end

  defdsl :defextractcondition do |slug, name: raise, operator: true, args: 0, sexp: nil, &block|
    if sexp
      filter_extract_condition do |conditions|
        conditions << Plugin::Extract::ExtensibleSexpCondition.new(slug, name, operator, args, sexp).freeze
        [conditions] end
    else
      filter_extract_condition do |conditions|
        conditions << Plugin::Extract::ExtensibleCondition.new(slug, name, operator, args, &block).freeze
        [conditions] end end end

  defdsl :defextractoperator do |slug, name: raise, args: 1, &block|
    filter_extract_operator do |operators|
      operators << Plugin::Extract::ExtensibleOperator.new(slug, name, args, &block).freeze
      [operators] end end

  defdsl :defextractorder do |slug, name:, &block|
    slug = slug.to_sym
    name = name.to_s.freeze
    collection(:extract_order) do |mutation|
      mutation.add(Plugin::Extract::Order.new(slug, name, block))
    end
  end

  defextractoperator(:==, name: _('＝'), args: 1, &:==)
  defextractoperator(:!=, name: _('≠'), args: 1, &:!=)
  defextractoperator(:match_regexp, name: _('正規表現'), args: 1, &:match_regexp)
  defextractoperator(:include?, name: _('含む'), args: 1, &:include?)

  defextractcondition(:user, name: _('ユーザ名'), operator: true, args: 1, sexp: MIKU.parse("`(,compare (idname (user message)) ,(car args))"))

  defextractcondition(:body, name: _('本文'), operator: true, args: 1, sexp: MIKU.parse("`(,compare (description message) ,(car args))"))

  defextractcondition(:source, name: _('投稿したクライアントアプリケーション名'), operator: true, args: 1, sexp: MIKU.parse("`(,compare (fetch message 'source) ,(car args))"))

  defextractcondition(:receiver_idnames, name: _('宛先ユーザ名のいずれか一つ以上'), operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.receive_user_idnames.any? do |sn|
      compare.(sn, arg)
    end
  end

  defextractorder(:created, name: _('投稿時刻')) do |model|
    model.created.to_i
  end

  defextractorder(:modified, name: _('投稿時刻 (ふぁぼやリツイートでageる)')) do |model|
    model.modified.to_i
  end

  on_extract_tab_create do |setting|
    if setting.is_a?(Hash)
      setting = Plugin::Extract::Setting.new(setting)
    end
    extract_tabs[setting.slug] = setting
    tab(setting.slug, setting.name) do
      set_icon setting.icon.to_s if setting.icon?
      timeline setting.slug do
        oo = setting.find_ordering_obj
        order(&setting.find_ordering_obj.ordering) if oo
      end
    end
    modify_extract_tabs end

  on_extract_tab_update do |setting|
    extract_tabs[setting.slug] = setting
    tab(setting.slug).set_icon setting.icon.to_s if setting.icon?
    oo = setting.find_ordering_obj
    timeline(setting.slug).order(&oo.ordering) if oo
    modify_extract_tabs end

  on_extract_tab_delete do |slug|
    if extract_tabs.has_key? slug
      deleted_tab = extract_tabs[slug]
      tab(deleted_tab.slug).destroy
      extract_tabs.delete(slug)
      modify_extract_tabs end end

  on_extract_tab_delete_with_confirm do |slug|
    extract = extract_tabs[slug]
    if extract
      message = _("本当に抽出タブ「%{name}」を削除しますか？") % {name: extract.name}
      dialog = Gtk::MessageDialog.new(nil,
                                      Gtk::Dialog::DESTROY_WITH_PARENT,
                                      Gtk::MessageDialog::QUESTION,
                                      Gtk::MessageDialog::BUTTONS_YES_NO,
                                      message)
      dialog.run{ |response|
        if Gtk::Dialog::RESPONSE_YES == response
          Plugin.call :extract_tab_delete, slug end
        dialog.close } end end

  on_extract_tab_open_create_dialog do
    dialog = Gtk::Dialog.new(_("抽出タブを作成 - %{mikutter}") % {mikutter: Environment::NAME}, nil, nil,
                             [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT],
                             [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT])
    prompt = Gtk::Entry.new
    dialog.vbox.
      add(Gtk::HBox.new(false, 8).
          closeup(Gtk::Label.new(_("名前"))).
          add(prompt).show_all)
    dialog.run{ |response|
      if Gtk::Dialog::RESPONSE_ACCEPT == response
        Plugin.call(:extract_tab_create, Plugin::Extract::Setting.new(name: prompt.text))
      end
      dialog.destroy
      prompt = dialog = nil } end

  on_extract_open_edit_dialog do |extract_slug|
    window = ::Plugin::Extract::EditWindow.new(extract_tabs[extract_slug], self)
    event = on_extract_tab_update do |setting|
      if extract_slug == setting.slug && !window.destroyed?
        window.refresh_title
      end
    end
    window.ssc(:destroy) do
      event.detach
      false
    end
  end

  # TODO: extract_datasourcesを非推奨に、message_streamを使う
  filter_extract_datasources do |ds_dict|
    [{ **ds_dict,
       **collect(:message_stream).map { |ms| [ms.datasource_slug.to_sym, ms.title] }.to_h
     }]
  end

  filter_extract_tabs_get do |tabs|
    [tabs + extract_tabs.values]
  end

  filter_active_datasources do |ds|
    [ds + active_datasources]
  end

  # 抽出タブの現在の内容を保存する
  def modify_extract_tabs
    UserConfig[:extract_tabs] = extract_tabs.values.map(&:export_to_userconfig)
    old_subscribers = @datasource_subscribers
    @datasource_subscribers = handler_tag do
      extract_tabs.values.each do |tab|
        tl = timeline(tab.slug)
        tab.sources.map { |source|
          subscribe(:extract_receive_message, source)
        }&.yield_self { |a, *rest|
          rest.empty? ? a : a.merge(*rest)
        }&.map { |message|
          message.retweet_source || message
        }&.select(&compile(tab.slug, tab.sexp))
          &.reject(&tl.method(:include?))
          &.each(&tl.method(:<<))
        if tab.popup?
          subscribe(:gui_timeline_add_messages, tl).select(&message_created_after_load_proc).each do |message|
            Plugin.call(:popup_notify, message.user, message.description)
          end
        end
        if tab.sound&.yield_self { |sound_uri| FileTest.exist?(sound_uri.to_s) }
          subscribe(:gui_timeline_add_messages, tl).select(&message_created_after_load_proc).each do
            Plugin.call(:play_sound, tab.sound.to_s)
          end
        end
      end
    end
    old_subscribers&.yield_self(&method(:detach))
    self
  end

  # 使用されているデータソースのSetを返す
  def active_datasources
    @active_datasources ||=
      extract_tabs.values.map{|tab|
      tab.sources
    }.inject(Set.new, &:merge).freeze
  end

  def compile(tab_slug, code)
    if code.empty?
      :itself.to_proc
    else
      begin
        before = Set.new
        extract_condition ||= Hash[Plugin.filtering(:extract_condition, []).first.map{ |condition| [condition.slug, condition] }]
        evaluated =
          MIKU::Primitive.new(:to_ruby_ne).call(
            MIKU::SymbolTable.new,
            metamorphose(
              code: code,
              assign: before,
              extract_condition: extract_condition
            )
          )
        instance_eval(['->(message) do', *before, evaluated, 'end'].join("\n"))
      rescue Plugin::Extract::ConditionNotFoundError => exception
        Plugin.call(:modify_activity,
                    plugin: self,
                    kind: 'error',
                    title: _('抽出タブ条件エラー'),
                    date: Time.new,
                    description: _("抽出タブ「%{tab_name}」で使われている条件が見つかりませんでした:\n%{error_string}") % {tab_name: extract_tabs[tab_slug].name, error_string: exception.to_s})
        warn exception
        :itself.to_proc
      end
    end
  end

  # 条件をこう、くいっと変形させてな
  def metamorphose(code: raise, assign: Set.new, extract_condition: nil)
    extract_condition ||= Hash[Plugin.filtering(:extract_condition, []).first.map{ |condition| [condition.slug, condition] }]
    case code
    when MIKU::Atom
      return code
    when MIKU::List
      return true if code.empty?
      condition = if code.size <= 2
                    extract_condition[code.car]
                  else
                    extract_condition[code.cdr.car] end
      case condition
      when Plugin::Extract::ExtensibleSexpCondition
        metamorphose_sexp(code: code, condition: condition)
      when Plugin::Extract::ExtensibleCondition
        assign << "#{condition.slug} = Class.new(Plugin::Extract::Calc).new(message, extract_condition[:#{condition.slug}])"
        if condition.operator
          code
        else
          # MIKU::Cons.new(:call, MIKU::Cons.new(condition.slug, nil))
          [:call, condition.slug]
        end
      else
        if code.cdr.car.is_a? Symbol and not %i[and or not].include?(code.car)
          raise Plugin::Extract::ConditionNotFoundError, _('抽出条件 `%{condition}\' が見つかりませんでした') % {condition: code.cdr.car} end
        code.map{|node| metamorphose(code: node,
                                     assign: assign,
                                     extract_condition: extract_condition) } end end end

  def metamorphose_sexp(code: raise, condition: raise)
    miku_context = MIKU::SymbolTable.new
    miku_context[:compare] = MIKU::Cons.new(code.car, nil)
    miku_context[:args] = MIKU::Cons.new(code.cdr.cdr, nil)
    begin
      miku(condition.sexp, miku_context)
    rescue => exception
      error "error occurred in code #{MIKU.unparse(condition.sexp)}"
      error miku_context
      raise exception end end

  (UserConfig[:extract_tabs] or []).each do |record|
    Plugin.call(:extract_tab_create, Plugin::Extract::Setting.new(record))
  end

  on_userconfig_modify do |key, val|
    next if key != :extract_tabs
    @active_datasources = nil
  end
end
