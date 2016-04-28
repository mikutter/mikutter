# -*- coding: utf-8 -*-

module Miquire::ToSpec
  refine Symbol do
    def to_spec
      Miquire::Plugin.get_spec_by_slug(self)
    end
  end

  refine String do
    def to_spec
      to_sym.to_spec
    end
  end

  refine Hash do
    def to_spec
      self
    end
  end
end
