ENV['BUNDLE_GEMFILE'] = File.expand_path(File.join(File.dirname(__FILE__), "..", "Gemfile"))
require 'rubygems'
require 'bundler/setup'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'test/unit'
require 'mocha'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'..','core'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'utils'
require 'miquire'
require 'test_unit_extensions'

miquire :boot, 'delayer'

