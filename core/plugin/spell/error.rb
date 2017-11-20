# -*- coding: utf-8 -*-

module Plugin::Spell
  Error = Class.new(StandardError)
  SpellNotFoundError = Class.new(Error)
  ConditionMismatchError = Class.new(Error)
end
