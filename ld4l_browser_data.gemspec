# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ld4l_browser_data/version'

Gem::Specification.new do |spec|
  spec.name          = "ld4l_browser_data"
  spec.version       = Ld4lBrowserData::VERSION
  spec.authors       = ["Jim Blake"]
  spec.email         = ["jeb228@cornell.edu"]

  spec.summary       = %q{TODO: Write a short summary, because Rubygems requires one.}
  spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  
  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"

  spec.add_runtime_dependency 'childprocess'
  spec.add_runtime_dependency 'json_pure'
  spec.add_runtime_dependency 'mysql2'
  spec.add_runtime_dependency 'rdf'
  spec.add_runtime_dependency 'rdf-json'
  spec.add_runtime_dependency 'rdf-raptor' # Can we get rid of this? Should we?
  spec.add_runtime_dependency 'rdf-rdfxml'
  spec.add_runtime_dependency 'rdf-turtle'
  spec.add_runtime_dependency 'ruby-xxHash'
end
