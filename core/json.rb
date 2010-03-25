miquire :core, 'json/common'
module JSON
  miquire :core, 'json/version'

  begin
    miquire :core, 'json/ext'
  rescue LoadError
    miquire :core, 'json/pure'
  end
end
