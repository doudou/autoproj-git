# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'autoproj/git/version'

Gem::Specification.new do |spec|
  spec.name          = "autoproj-git"
  spec.version       = Autoproj::Git::VERSION
  spec.authors       = ["Sylvain Joyeux"]
  spec.email         = ["sylvain.joyeux@m4x.org"]

  spec.summary       = "git-aware plugin for autoproj"
  spec.description   = "This autoproj plugin provides git-specific functionality for autoproj, such as management of github-like PRs, automatic cleanup, ..."
  spec.homepage      = "https://github.com/doudou/autoproj-git"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "autoproj", ">= 2.0.0.a"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0", ">= 5.0"
end
