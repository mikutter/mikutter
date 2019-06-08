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
    dialog = Gtk::Dialog.new
    dialog.window_position = Gtk::Window::POS_CENTER
    dialog.title = "Quick Step"
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT)
    register_listeners(dialog, put_widget(dialog.vbox))
    dialog.show_all
  end

  intent Plugin::Quickstep::Command, label: 'mikutterコマンド' do |intent_token|
    window = Plugin::GUI::Window.active
    command = intent_token.model
    event = Plugin::GUI::Event.new(:quickstep, window, [])
    command[:exec].call(event) if command[:condition] === event
  end

  # URLっぽい文字列なら、それに対してintentを発行する候補を出す
  filter_quickstep_query do |query, yielder|
    if URI::DEFAULT_PARSER.make_regexp.match?(query)
      yielder << Retriever::URI!(query)
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
    search.ssc(:activate, &gen_query_box_activated)
    box.closeup(search).add(complete)
    complete
  end

  def gen_query_box_activated
    ->(search) do
      dialog = search.get_ancestor(Gtk::Dialog)
      dialog.signal_emit(:response, Gtk::Dialog::RESPONSE_ACCEPT) if dialog
      false
    end
  end

  def register_listeners(dialog, treeview)
    dialog.ssc(:response) do |widget, response|
      case response
      when Gtk::Dialog::RESPONSE_ACCEPT
        selected = treeview.selection.selected
        Plugin.call(:open, selected[Plugin::Quickstep::Store::COL_MODEL]) if selected
      end
      widget.destroy
      false
    end
  end
end
