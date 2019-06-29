# -*- coding: utf-8 -*-
require_relative 'complete'
require_relative 'model/command'
Plugin.create(:quickstep) do
  command(:quickstep,
          name: 'Quick Step',
          condition: lambda { |opt| true },
          icon: Skin[:search],
          visible: true,
          role: :window) do |opt|
    tab(:quickstep, "QuickStep 検索") do
      set_icon Skin[:search]
      set_deletable true
      temporary_tab true
      box = Gtk::VBox.new
      put_widget(box)
      nativewidget box
      active!
    end
  end

  intent Plugin::Quickstep::Command, label: 'mikutterコマンド' do |intent_token|
    window = Plugin::GUI::Window.active
    command = intent_token.model
    world, = Plugin.filtering(:world_current, nil)
    event = Plugin::GUI::Event.new(event: :quickstep,
                                   widget: window,
                                   world: world,
                                   messages: [])
    command[:exec].call(event) if command[:condition] === event
  end

  # URLっぽい文字列なら、それに対してintentを発行する候補を出す
  filter_quickstep_query do |query, yielder|
    if URI::DEFAULT_PARSER.make_regexp.match?(query)
      yielder << Diva::URI!(query)
    end
    [query, yielder]
  end

  filter_quickstep_query do |query, yielder|
    if !query.empty?
      commands, = Plugin.filtering(:command, Hash.new)
      commands.each do |command_slug, options|
        if options[:role] == :window and (options[:name].include?(query) or command_slug.to_s.include?(query))
          yielder << Plugin::Quickstep::Command.new(options.merge(slug: command_slug))
        end
      end
    end
    [query, yielder]
  end

  def put_widget(box)
    search = Gtk::Entry.new
    complete = Plugin::Quickstep::Complete.new(search)
    search.ssc(:activate, &gen_search_activate_callback(complete))
    search.ssc(:realize, &gen_search_realize_callback)
    search.ssc(:key_press_event, &gen_common_shortcutkey_callback)
    complete.ssc(:key_press_event, &gen_common_shortcutkey_callback)
    box.closeup(search).add(complete)
    complete
  end

  private

  def gen_search_activate_callback(complete)
    ->(_) do
      tab(:quickstep).destroy
      selected = complete.selection.selected
      Plugin.call(:open, selected[Plugin::Quickstep::Store::COL_MODEL]) if selected
    end
  end

  def gen_search_realize_callback
    ->(this) do
      this.get_ancestor(Gtk::Window).set_focus(this)
      false
    end
  end

  def gen_common_shortcutkey_callback
    ->(widget, event) do
      case ::Gtk::keyname([event.keyval, event.state])
      when 'Escape'
        tab(:quickstep).destroy
        true
      end
    end
  end
end
