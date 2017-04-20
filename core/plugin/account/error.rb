# -*- coding: utf-8 -*-
module Plugin::Account
  Error = Class.new(StandardError)
  InvalidAccountError = Class.new(Error)
  NotExistError = Class.new(Error)
end
