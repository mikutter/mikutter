# -*- coding: utf-8 -*-
require_relative 'model/web'

Plugin.create(:web) do
  intent Plugin::Web::Web, label: _('外部ブラウザで開く') do |intent_token|
    Gtk.openurl(intent_token.model.perma_link.to_s)
  end
end
