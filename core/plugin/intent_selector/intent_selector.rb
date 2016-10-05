# -*- coding: utf-8 -*-

Plugin.create(:intent_selector) do
  on_intent_select do |intents, model|
    case model
    when Retriever::Model
      intent_choose_dialog(intents, model: model)
    when URI
      intent_choose_dialog(intents, uri: model)
    when String
      intent_choose_dialog(intents, model: URI.parse(model))
    end
  end

  def intent_choose_dialog(intents, model: nil, uri: model.uri)
    dialog = Gtk::Dialog.new('開く - %{application_name}' % {application_name: Environment::NAME})
    dialog.window_position = Gtk::Window::POS_CENTER
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
    dialog.add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL)
    dialog.vbox.closeup(Gtk::Label.new("%{uri} \nを開こうとしています。どの方法で開きますか？" % {uri: uri}, false))
    selected_intent = nil
    intents.inject(nil) do |group, intent|
      if group
        radio = Gtk::RadioButton.new(group, intent.label)
      else
        selected_intent = intent
        radio = Gtk::RadioButton.new(intent.label) end
      radio.ssc(:toggled) do |w|
        selected_intent = intent
        false
      end
      radio.ssc(:activate) do |w|
        selected_intent = intent
        dialog.signal_emit(:response, Gtk::Dialog::RESPONSE_OK)
        false
      end
      dialog.vbox.closeup(radio)
      group || radio
    end
    dialog.ssc(:response) do |w, response_id|
      if response_id == Gtk::Dialog::RESPONSE_OK and selected_intent
        Plugin::Intent::IntentToken.open(
          uri: uri,
          model: model,
          intent: selected_intent,
          parent: nil)
      end
      w.destroy
    end
    dialog.show_all
  end
end
