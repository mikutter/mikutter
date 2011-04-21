# -*- coding: utf-8 -*-
miquire :json, 'common'
module JSON
  miquire :json, 'version'

  begin
    miquire :json, 'ext'
  rescue LoadError
    miquire :json, 'pure'
  end
end
