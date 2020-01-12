# -*- coding: utf-8 -*-
# frozen_string_literal: true

Plugin.create :quoted_message do
  command(:copy_message_permalink,
          name: ->(opt) {
            if opt
              _('%{model_label}のURLをコピー') % {model_label: opt&.messages&.first&.class&.spec&.name }
            else
              _('この投稿のURLをコピー')
            end
          },
          condition: ->(opt) { opt.messages.all?(&:perma_link) },
          visible: true,
          role: :timeline) do |opt|
    Gtk::Clipboard.copy(opt.messages.map(&:perma_link).join("\n"))
  end

  command(:quoted_message,
          name: _('URLを引用して投稿'),
          icon: Skin[:quote],
          condition: ->(opt) { opt.messages.all?(&:perma_link) },
          visible: true,
          role: :timeline) do |opt|
    messages = opt.messages
    opt.widget.create_postbox(to: messages,
                              footer: ' ' + messages.map(&:perma_link).join(' '),
                              to_display_only: true)
  end
end
