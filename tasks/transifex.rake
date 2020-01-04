# -*- coding: utf-8 -*-
namespace 'transifex' do
  task 'upload' do
    require 'tmpdir'
    require 'httpclient'
    require 'json'
    require 'set'
    require_relative '../core/boot/option'
    require_relative '../core/miquire'
    require_relative 'transifex'

    require 'boot/delayer'
    require 'miquire_plugin'

    project_name = ENV['TRANSIFEX_PROJECT_NAME']

    Dir.mktmpdir('mikutter-transifex-upload') do |confroot|
      Mopt.parse(["--confroot=#{confroot}"], exec_command: false)
      project = Transifex.project_detail(project_name)
      existing_resource_slugs = Set.new(project[:resources].map{|res|res[:slug].to_sym})
      Environment::PLUGIN_PATH.each do |path|
        Miquire::Plugin.loadpath << path
      end
      Miquire::Plugin.loadpath << File.join(__dir__, "..", "plugin")
      Miquire::Plugin.each_spec do |spec|
        pot_path = File.join(spec[:path], 'po', "#{spec[:slug]}.pot")
        next unless FileTest.exist?(pot_path)
        slug = spec[:slug] == :settings ? 'settings-1' : spec[:slug]
        if existing_resource_slugs.include? slug.to_sym
          puts "Update #{slug}"
          pp Transifex.resource_update(project_name: project_name,
                                       slug: slug,
                                       content: File.open(pot_path).map(&:chomp).reject{|l|
                                         l == '"Plural-Forms: nplurals=INTEGER; plural=EXPRESSION;\n"'
                                       }.reject{|l|
                                         l == '#, fuzzy'
                                       }.join("\n")
                                      )
        else
          puts "Create #{spec[:slug]}"
          pp Transifex.resource_create(project_name: project_name,
                                       slug: slug,
                                       name: spec[:slug], # 表示名を日本語にすると外人が核ミサイルを撃ってくるかもしれない
                                       content: File.open(pot_path).map(&:chomp).reject{|l|
                                         l == '"Plural-Forms: nplurals=INTEGER; plural=EXPRESSION;\n"'
                                       }.reject{|l|
                                         l == '#, fuzzy'
                                       }.join("\n")
                                      )
        end
      end
    end
  end
end

