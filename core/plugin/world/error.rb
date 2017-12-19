# -*- coding: utf-8 -*-
module Plugin::World
  Error = Class.new(StandardError)
  InvalidWorldError = Class.new(Error)
  NotExistError = Class.new(Error)
end
