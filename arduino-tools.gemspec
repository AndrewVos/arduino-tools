# -*- encoding: utf-8 -*-
require File.expand_path('../lib/arduino-tools/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Andrew Vos"]
  gem.email         = ["andrew.vos@gmail.com"]
  gem.description   = %q{Arduino Tools}
  gem.summary       = %q{}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "arduino-tools"
  gem.require_paths = ["lib"]
  gem.version       = Arduino::Tools::VERSION
end
