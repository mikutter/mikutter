# -*- coding: utf-8 -*-

miquire :lib, "gettext"

module Plugin::UITranslate
  LocaleDirectory = File.join(CHIConfig::CACHE, "uitranslator", "locale")
end

Plugin.create :uitranslator do
  FileUtils.mkdir_p Plugin::UITranslate::LocaleDirectory
end

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

        Dir.glob(File.join(po_root, "*/*.po")) do |po_file|
          lang, textdomain = %r[/([^/]+?)/(.*)\.po].match(po_file[po_root.size..-1]).to_a[1,2]
          mo_file = File.join(mo_root, "#{lang}/LC_MESSAGES", "#{textdomain}.mo")
          FileUtils.mkdir_p(File.dirname(mo_file))
          GetText::Tools::MsgFmt.run(po_file, "-o", mo_file)
        end

      end
      bindtextdomain(to_s, path: Plugin::UITranslate::LocaleDirectory)
    end
    spec
  end
end


