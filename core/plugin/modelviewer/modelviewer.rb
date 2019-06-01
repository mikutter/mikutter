# frozen_string_literal: true

Plugin.create :modelviewer do
  defdsl :defmodelviewer do |model_class, &block|
    model_class = Diva::Model(model_class) unless model_class.is_a?(Class)
    notice model_class
    intent(model_class,
           label: _('%<model>sの詳細') % {model: model_class.name},
           slug: :"modelviewer:#{model_class.slug}"
          ) do |token|
      model = token.model
      tab_slug = :"modelviewer:#{model_class.slug}:#{model.uri.hash}"
      if Plugin::GUI::Tab.exist?(tab_slug)
        Plugin::GUI::Tab.instance(tab_slug).active!
      else
        tab(tab_slug, _('%<model>sの詳細')) do
          set_icon model.icon if model.respond_to?(:icon)
          set_deletable true
          temporary_tab true
          shrink
          nativewidget Plugin[:modelviewer].header(token, &block)
          expand
          Plugin[:modelviewer].cluster_initialize(model, cluster(nil))
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
      i_fragment = Plugin::GUI::Fragment.instance(:"#{slug}:#{model.uri}", title)
      i_fragment.instance_eval_with_delegate(self, model, &block)
      tabs << i_fragment
      [tabs, model]
    end
  end


  def cluster_initialize(model, i_cluster)
    Enumerator.new { |y|
      Plugin.filtering(:"modelviewer_#{model.class.slug}_fragments", y, model)
    }.each{|tab|
      i_cluster << tab
    }
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

  def header_table(model, header_columns)
    ::Gtk::Table.new(2, header_columns.size).tap{|table|
      header_columns.each_with_index do |column, index|
        key, value = column
        table.
          attach(::Gtk::Label.new(key.to_s).right, 0, 1, index, index+1).
          attach(::Gtk::Label.new(value.to_s).left , 1, 2, index, index+1)
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
