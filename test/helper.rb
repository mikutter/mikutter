require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'..','core'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'boot/option'
require 'utils'
require 'miquire'
require 'test_unit_extensions'
# require File.expand_path(File.dirname(__FILE__)+'/../core/boot/option')
# require File.expand_path(File.dirname(__FILE__)+'/../core/utils')
# require File.expand_path(File.dirname(__FILE__)+'/../core/miquire')
# require File.expand_path(File.dirname(__FILE__)+'/../core/lib/test_unit_extensions')
