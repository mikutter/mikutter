# frozen_string_literal: true

Plugin.create :modelviewer do
  defdsl :defmodelviewer do |model_class, &block|
    model_class = Diva::Model(model_class) unless model_class.is_a?(Class)
    filter_modelviewer_models do |models|
      models << model_class.spec
      [models]
    end
    intent(model_class,
           label: _('%{model}の詳細') % {model: model_class.spec&.name || model_class.name},
           slug: :"modelviewer:#{model_class.slug}"
          ) do |token|
      model = token.model
      tab_slug = :"modelviewer:#{model_class.slug}:#{model.uri.hash}"
      cluster_slug = :"modelviewer-cluster:#{model_class.slug}:#{model.uri.hash}"
      if Plugin::GUI::Tab.exist?(tab_slug)
        Plugin::GUI::Tab.instance(tab_slug).active!
      else
        tab(tab_slug, _('%{title}について') % {title: model.title}) do
          set_icon model.icon if model.respond_to?(:icon)
          set_deletable true
          temporary_tab true
          shrink
          nativewidget Plugin[:modelviewer].header(token, &block)
          expand
          Plugin[:modelviewer].cluster_initialize(model, cluster(cluster_slug))
          active!
        end
      end
    end
  end

  # プロフィールタブを定義する
  # ==== Args
  # [slug] タブスラッグ
  # [title] タブのタイトル
  defdsl :deffragment do |model_class, slug, title=slug.to_s, &block|
    model_class = Diva::Model(model_class) unless model_class.is_a?(Class)
    add_event_filter(:"modelviewer_#{model_class.slug}_fragments") do |tabs, model|
      i_fragment = Plugin::GUI::Fragment.instance(:"modelviewer-fragment:#{slug}:#{model.uri}", title)
      i_fragment.instance_eval_with_delegate(self, model, &block)
      tabs << i_fragment
      [tabs, model]
    end
  end

  on_gui_child_reordered do |i_cluster, i_fragment, order|
    kind, = i_fragment.slug.to_s.split(':', 2)
    if kind == 'modelviewer-fragment'
      _, cluster_kind, = i_cluster.slug.to_s.split(':', 3)
      store("order-#{cluster_kind}", i_cluster.children.map { |f| f.slug.to_s.split(':', 3)[1] })
    end
  end

  def cluster_initialize(model, i_cluster)
    _, cluster_kind, = i_cluster.slug.to_s.split(':', 3)
    order = at("order-#{cluster_kind}", [])
    fragments = Enumerator.new { |y|
      Plugin.filtering(:"modelviewer_#{model.class.slug}_fragments", y, model)
    }.sort_by { |i_fragment|
      _, fragment_kind, = i_fragment.slug.to_s.split(':', 3)
      order.index(fragment_kind) || Float::INFINITY
    }.to_a
    fragments.each(&i_cluster.method(:add_child))
    fragments.first&.active!
  end

  def header(intent_token, &column_generator)
    model = intent_token.model
    eventbox = ::Gtk::EventBox.new
    eventbox.ssc(:visibility_notify_event){
      eventbox.style = background_color
      false
    }

    icon_alignment = Gtk::Alignment.new(0.5, 0, 0, 0)
                       .set_padding(*[UserConfig[:profile_icon_margin]]*4)

    eventbox.add(
      ::Gtk::VBox.new(false, 0).
        add(
          ::Gtk::HBox.new
            .closeup(icon_alignment.add(model_icon(model)))
            .add(
              ::Gtk::VBox.new
                .closeup(title_widget(model, intent_token))
                .closeup(header_table(model, column_generator.(model)))
            )
        )
    )
  end

  def model_icon(model)
    return ::Gtk::EventBox.new unless model.respond_to?(:icon)
    icon = ::Gtk::EventBox.new.add(::Gtk::WebIcon.new(model.icon, UserConfig[:profile_icon_size], UserConfig[:profile_icon_size]).tooltip(_('アイコンを開く')))
    icon.ssc(:button_press_event) do |this, event|
      Plugin.call(:open, model.icon)
      true
    end
    icon.ssc(:realize) do |this|
      this.window.set_cursor(Gdk::Cursor.new(Gdk::Cursor::HAND2))
      false
    end
    icon
  end

  # modelのtitleを表示する
  # ==== Args
  # [model] 表示するmodel
  # [intent_token] ユーザを開くときに利用するIntent
  # ==== Return
  # ユーザの名前の部分のGtkコンテナ
  def title_widget(model, intent_token)
    score = [
      Plugin::Score::HyperLinkNote.new(
        description: model.title,
        uri: model.uri
      )
    ]
    ::Gtk::IntelligentTextview.new(score, style: style)
  end

  # modelのtitleを表示する
  # ==== Args
  # [model] 表示するmodel
  # [intent_token] ユーザを開くときに利用するIntent
  # ==== Return
  # ユーザの名前の部分のGtkコンテナ
  def cell_widget(model_or_str)
    case model_or_str
    when Diva::Model
      ::Gtk::IntelligentTextview.new(
        Plugin[:modelviewer].score_of(model_or_str),
        style: style
      )
    else
      ::Gtk::IntelligentTextview.new(model_or_str.to_s, style: style)
    end
  end

  def header_table(model, header_columns)
    ::Gtk::Table.new(2, header_columns.size).tap{|table|
      header_columns.each_with_index do |column, index|
        key, value = column
        table.
          attach(::Gtk::Label.new(key.to_s).right, 0, 1, index, index+1).
          attach(cell_widget(value), 1, 2, index, index+1)
      end
    }.set_row_spacing(0, 4).
      set_row_spacing(1, 4).
      set_column_spacing(0, 16)
  end

  def style
    -> do
      Gtk::Style.new().tap do |bg_style|
        color = UserConfig[:mumble_basic_bg]
        bg_style.set_bg(Gtk::STATE_ACTIVE, *color)
        bg_style.set_bg(Gtk::STATE_NORMAL, *color)
        bg_style.set_bg(Gtk::STATE_SELECTED, *color)
        bg_style.set_bg(Gtk::STATE_PRELIGHT, *color)
        bg_style.set_bg(Gtk::STATE_INSENSITIVE, *color)
      end
    end
  end

  def background_color
    style = ::Gtk::Style.new()
    style.set_bg(::Gtk::STATE_NORMAL, 0xFF ** 2, 0xFF ** 2, 0xFF ** 2)
    style
  end
end
