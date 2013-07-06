# -*- coding: utf-8 -*-

miquire :lib, "gettext"#, 'gettext/tools'

module Plugin::UITranslate
  LocaleDirectory = File.join(CHIConfig::CACHE, "uitranslator", "locale")
end

Plugin.create :uitranslator do
  FileUtils.mkdir_p Plugin::UITranslate::LocaleDirectory
end
# include GetText
# bindtextdomain("setting", path: Plugin::UITranslate::LocaleDirectory)

class Plugin
  include GetText

  alias __spec_uitranslate__ spec=
  def spec=(spec)
	__spec_uitranslate__(spec)

    po_root = File.join spec[:path], "po"
    mo_root = Plugin::UITranslate::LocaleDirectory
    mo = File.join(mo_root, "#{spec[:slug]}.mo")
    if FileTest.exist?(po_root)
      bound = lazy{ File.mtime(mo) }
      if !FileTest.exist?(mo) or Dir.glob(File.join(po_root, "*/*.po")).any?{ |po| File.mtime(po) > bound }
        miquire :lib, "gettext/tools"
        notice "generate mo file: #{po_root} to #{mo_root}"
        GetText.create_mofiles po_root: po_root, mo_root: mo_root
      end
      bindtextdomain(to_s, path: Plugin::UITranslate::LocaleDirectory)
    end
    spec
  end
end


