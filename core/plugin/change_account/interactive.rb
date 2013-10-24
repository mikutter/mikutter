# -*- coding: utf-8 -*-

module Plugin::ChangeAccount
  module InteractiveMixin
    def say(message, choose = {Plugin[:change_account]._('次へ') => nil})
      self.next {
        promise = Deferred.new(true).extend(InteractiveMixin)
        Plugin.call(:update, nil,
                    [Message.new(message: message,
                                 system: true,
                                 source: "change_account",
                                 created: Time.now,
                                 confirm: choose,
                                 confirm_callback: promise)])
        promise
      }
    end

    def next
      super(&Proc.new).extend(InteractiveMixin) end

    def trap
      super(&Proc.new).extend(InteractiveMixin) end

  end

  class Interactive < Deferred
    include InteractiveMixin

    def self.generate
      Deferred.new.extend(InteractiveMixin)
    end
  end

  class SubPartsTutorial < Gdk::SubParts
    Button = Struct.new(:layout, :value, :x, :y, :width, :height)
    OutsideOffset = 48          # 最初のボタンの左端との隙間
    ButtonLeft = 4              # ボタンの左端と文字の左側の距離
    ButtonRight = 4             # ボタンの右端と文字の右側の距離
    ButtonTop = 4               # わかるよね
    ButtonBottom = 4            # わかるよね
    ButtonMargin = 4            # ボタンとボタンの距離

    regist

    def initialize(*args)
      super
      if message[:confirm]
        sid = helper.ssc(:click){ |this, e, x, y|
          ofsty = helper.mainpart_height
          helper.subparts.each{ |part|
            break if part == self
            ofsty += part.height }
          if ofsty <= y and (ofsty + height) >= y and 1 == e.button
            button = generate_buttons.find{|b| b.x < x and x < (b.x+b.width) }
            if button
              helper.signal_handler_disconnect(sid)
              message[:confirm] = nil
              helper.reset_height
              message[:confirm_callback].call(button.value) end end
          false } end
    end

    def render(context)
      if helper.visible? and message and message[:confirm]
        context.save{
          buttons = generate_buttons(context)
          return if not buttons
          buttons.each{ |button|
            context.save{
              context.translate(button.x + ButtonLeft, button.y + ButtonTop)
              context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
              context.show_pango_layout(button.layout) } } } end end

    def height
      buttons = generate_buttons
      return 0 if not buttons
      @height ||= (buttons.map{|b|b.layout.size[1]}.max / Pango::SCALE) + ButtonMargin*2 end

    private

    def generate_buttons(context = dummy_context)
      if not message[:confirm]
        return nil end
      ofst = OutsideOffset + ButtonMargin
      message[:confirm].map{ |label, value|
        layout = context.create_pango_layout
        layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
        layout.text = label
        width = layout.size[0]/Pango::SCALE + ButtonLeft + ButtonRight
        x = ofst
        ofst += width + ButtonMargin
        Button.new(layout, value,
                   x, 0,
                   width,
                   layout.size[1]/Pango::SCALE + ButtonTop + ButtonBottom) } end

    def message
      helper.message end

  end

end
