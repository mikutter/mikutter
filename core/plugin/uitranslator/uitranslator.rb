# -*- coding: utf-8 -*-

require "gettext"

module Plugin::UITranslate
  LocaleDirectory = File.join(CHIConfig::CACHE, "uitranslator", "locale").freeze
  PODirectoryPrefix = 'po'.freeze
  LanguageMatcher = %r<#{PODirectoryPrefix}#{File::SEPARATOR}(\w+)#{File::SEPARATOR}.+?\.po\Z>.freeze
  LanguageFileInfo = Struct.new(:po, :mo)
end

Plugin.create :uitranslator do
  FileUtils.mkdir_p Plugin::UITranslate::LocaleDirectory
end

class Plugin
  include GetText

  alias __spec_uitranslate__ spec=
  def spec=(spec)
	__spec_uitranslate__(spec)

    po_root = File.join spec[:path], Plugin::UITranslate::PODirectoryPrefix
    if FileTest.exist?(po_root)
      Dir.glob(File.join(po_root, '*/*.po'.freeze)).map{|po_path|
        lang = po_path.match(Plugin::UITranslate::LanguageMatcher)[1]
        mo_path = File.join(Plugin::UITranslate::LocaleDirectory, lang, 'LC_MESSAGES'.freeze, "#{spec[:slug]}.mo")
        Plugin::UITranslate::LanguageFileInfo.new(po_path, mo_path)
      }.select{|info|
        if File.exist?(info.mo)
          File.mtime(info.po) > File.mtime(info.mo)
        else
          true end
      }.each{|info|
        require 'gettext/tools'
        FileUtils.mkdir_p(File.dirname(info.mo))
        GetText::Tools::MsgFmt.run(info.po, '-o'.freeze, info.mo)
        notice "generated mo file #{info.po} => #{info.mo}"
      }
      bindtextdomain(to_s, path: Plugin::UITranslate::LocaleDirectory)
    end
    spec
  end
end
