miquire :core, 'json/common'

module JSON
  # This module holds all the modules/classes that implement JSON's
  # functionality as C extensions.
  module Ext
    miquire :core, 'json/ext/parser'
    miquire :core, 'json/ext/generator'
    $DEBUG and warn "Using c extension for JSON."
    JSON.parser = Parser
    JSON.generator = Generator
  end

  JSON_LOADED = true
end
