# -*- coding: utf-8 -*-

module Plugin::World
  # Worldを復元するために必要なプラグインがロードできないときに、一時的にmikutterでそのWorldの代わりに使われる。
  # to_hashがfieldsの値をそのまま返すようになっている。
  class LostWorld < Diva::Model
    field.string :slug, required: true
    field.string :provider, required: true

    def initialize(fields)
      @fields = fields.freeze
      super
    end

    def icon
      Skin[:underconstruction]
    end

    def title
      "#{slug}(#{provider})"
    end

    def path
      "/#{provider.to_s}/#{slug.to_s}"
    end

    def to_hash
      @fields
    end
  end
end
