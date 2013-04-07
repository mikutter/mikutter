source 'https://rubygems.org'

gem 'gtk2', '~> 1.2.5'
gem 'oauth', '~> 0.4.7'
gem 'json_pure'
gem 'bsearch', '~> 1.5.0'
gem 'addressable'
gem 'memoize'
gem 'ruby-hmac'
gem 'typed-array'
gem 'bundler'

group :test do
  gem 'rake'
  gem 'watch'
  gem 'mocha'
  gem 'webmock'
end

Dir.glob(File.expand_path("~/.mikutter/plugin/*/Gemfile")){ |path|
  eval File.open(path).read
}
