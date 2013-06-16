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
    # if FileTest.exist?(po_root)
    #   notice "generate mo file: #{po_root} to #{mo_root}"
    #   GetText.create_mofiles po_root: po_root, mo_root: mo_root
    # end
    if FileTest.exist?(po_root)
      bindtextdomain(to_s, path: Plugin::UITranslate::LocaleDirectory)
      puts to_s
    end
    spec
  end
end


