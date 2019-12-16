alias __source_distinct__ source
def source(url)
  @loaded ||= {}
  unless @loaded[url]
    @loaded[url] = true
    __source_distinct__(url) end end

source 'https://rubygems.org'

ruby '>= 2.5.0'

group :default do
  gem 'addressable', '>= 2.6.0', '< 2.8'
  gem 'delayer', '>= 1.0.0', '< 1.1'
  gem 'delayer-deferred', '>= 2.1.0', '< 2.2'
  gem 'diva', '>= 1.0.0', '< 1.1'
  gem 'memoist', '>= 0.16', '< 0.17'
  gem 'oauth', '>= 0.5.4'
  gem 'pluggaloid', '>= 1.2.0', '< 1.3'
  #gem 'ruby-hmac', '~> 0.4.0'
  gem 'typed-array', '>= 0.1.2', '< 0.2'
end

group :test do
  gem 'test-unit', '>= 3.3.3', '< 4.0'
  gem 'rake', '>= 12.3.2'
  #gem 'watch'#, '~> 0.1'
  gem 'mocha', '>= 1.8.0'#, '~> 0.14'
  gem 'webmock', '>= 3.5.1'#, '~> 1.17'
  gem 'ruby-prof', '>= 0.18.0'
end


group :plugin do
  Dir.glob(File.expand_path(File.join(__dir__, 'core/plugin/*/Gemfile'))){ |path|
    eval File.open(path).read
  }
  Dir.glob(File.join(File.expand_path(ENV['MIKUTTER_CONFROOT'] || '~/.mikutter'), 'plugin/*/Gemfile')){ |path|
    eval File.open(path).read
  }
end
