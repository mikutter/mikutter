# -*- coding: utf-8 -*-
miquire :core, "miquire", "plugin"

# プラグインのロードに関すること
module Miquire::Plugin
  class << self
    include Enumerable

    # ロードパスの配列を返す。
    # ロードパスに追加したい場合は、以下のようにすればいい
    #
    #  Miquire::Plugin.loadpath << 'pathA' << 'pathB'
    def loadpath
      @loadpath ||= [] end

    # プラグインのファイル名(フルパス)で繰り返す。
    def each
      iterated = Set.new
      detected = []
      loadpath.reverse.each { |path|
        Dir[File.join(File.expand_path(path), '*')].each { |file|
          if FileTest.directory?(file) and FileTest.exist?(File.join(file, File.basename(file))+'.rb')
            file = File.join(file, File.basename(file))+'.rb'
          elsif not /\.rb$/ =~ file
            next end
          plugin_name = File.basename(file, '.rb')
          if not iterated.include? plugin_name
            iterated << plugin_name
            detected << file end } }
      detected.sort.each &Proc.new end

    def each_spec
      each{ |path|
        spec = get_spec path
        yield spec if spec } end

    def to_hash
      result = {}
      each_spec{ |spec|
        result[spec[:slug]] = spec }
      result end

    # 受け取ったパスにあるプラグインのスラッグを返す
    # ==== Args
    # [path] パス(String)
    # ==== Return
    # プラグインスラッグ(Symbol)
    def get_slug(path)
      type_strict path => String
      spec = get_spec(path)
      if spec
        spec[:slug]
      else
        File.basename(path, ".rb").to_sym end end

    # specファイルがあればそれを返す
    # ==== Args
    # [path] パス(String)
    # ==== Return
    # specファイルの内容か、存在しなければnil
    def get_spec(path)
      type_strict path => String
      plugin_dir = FileTest.directory?(path) ? path : File.dirname(path)
      spec_filename = File.join(plugin_dir, "spec")
      if FileTest.exist? spec_filename
        spec = YAML.load_file(spec_filename).symbolize
        spec[:path] = plugin_dir
        spec
      elsif FileTest.exist? path
        { slug: File.basename(path, ".rb").to_sym,
          path: plugin_dir } end end

    def get_spec_by_slug(slug)
      type_strict slug => Symbol
      to_hash[slug] end

    def load_all
      each_spec{ |spec|
        begin
          load spec
        rescue Miquire::LoadError => e
          ::Plugin.call(:modify_activity,
                        kind: "system",
                        title: "#{spec[:slug]} load failed",
                        date: Time.new,
                        exception: e,
                        description: e.to_s) end } end

    def load(spec)
      type_strict spec => tcor(Hash, Symbol, String)
      case spec
      when Symbol, String
        spec = spec.to_sym
        if ::Plugin.instance_exist?(spec)
          return true end
        spec = get_spec_by_slug(spec)
        if not spec
          return false end
      else
        if ::Plugin.instance_exist?(spec[:slug])
          return true end end

      if defined?(spec[:depends][:mikutter]) and spec[:depends][:mikutter]
        version = Environment::Version.new(*(spec[:depends][:mikutter].split(".").map(&:to_i) + ([0]*4))[0...4])
        if Environment::VERSION < version
          raise Miquire::LoadError, "plugin #{spec[:slug]}: #{Environment::NAME} version too old (#{spec[:depends][:mikutter]} required, but #{Environment::NAME} version is #{Environment::VERSION})"
          return false end end

      if defined? spec[:depends][:plugin]
        spec[:depends][:plugin].map(&:to_sym).each{ |depended_plugin_slug|
          begin
            ::Plugin.instance_exist?(depended_plugin_slug) or
              load(depended_plugin_slug) or
              raise Miquire::LoadError
          rescue Miquire::LoadError
            raise Miquire::LoadError, "plugin #{spec[:slug]}: dependency error: plugin #{depended_plugin_slug} was not loaded." end } end

      notice "plugin loaded: " + File.join(spec[:path], "#{spec[:slug]}.rb")
      Kernel.load File.join(spec[:path], "#{spec[:slug]}.rb")
      true end
  end
end
