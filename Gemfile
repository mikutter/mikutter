source 'https://rubygems.org'

group :default do
  gem 'oauth', '~> 0.4.7'
  gem 'json_pure'
  gem 'bsearch', '~> 1.5.0'
  gem 'addressable'
  gem 'memoize'
  gem 'ruby-hmac'
  gem 'typed-array'
  gem 'delayer'
end

group :test do
  gem 'rake'
  gem 'watch'
  gem 'mocha'
  gem 'webmock'
end

group :plugin do
  Dir.glob(File.expand_path(File.join(File.dirname(__FILE__), "core/plugin/*/Gemfile"))){ |path|
    eval File.open(path).read
  }
  Dir.glob(File.expand_path("~/.mikutter/plugin/*/Gemfile")){ |path|
    eval File.open(path).read
  }
end
