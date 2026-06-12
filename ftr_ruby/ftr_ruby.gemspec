# frozen_string_literal: true

# Robust way to load the version file during gem build
lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ftr_ruby/version"

Gem::Specification.new do |spec|
  spec.name          = "ftr_ruby"
  spec.version       = FtrRuby::VERSION
  spec.authors       = ["markwilkinson"]
  spec.email         = ["mark.wilkinson@upm.es"]
  spec.summary       = "Libraries supporting the FTR Vocabulary."
  spec.description   = "Libraries supporting the FAIR Testing Resources Vocabulary - Tests and test outputs."
  spec.homepage      = "https://github.com/markwilkinson/FTR-Ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "https://github.com/markwilkinson/FTR-Ruby"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/ftr_ruby"
  spec.metadata["bug_tracker_uri"]   = "https://github.com/markwilkinson/FTR-Ruby/issues"

  # Files to include in the gem
  gemspec_file = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      f == gemspec_file ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # ==================== RUNTIME DEPENDENCIES ====================

  spec.add_runtime_dependency "base64", "~> 0.3" # often needed with rest-client etc.
  spec.add_runtime_dependency "connection_pool", "~> 2.4", "< 3.0"
  spec.add_runtime_dependency "http", "~> 6.0"
  spec.add_runtime_dependency "json", "~> 2.7"
  spec.add_runtime_dependency "json-canonicalization", "~> 1.0"
  spec.add_runtime_dependency "jsonpath", "~> 1.1"
  spec.add_runtime_dependency "linkeddata", "~> 3.1"
  spec.add_runtime_dependency "multi_json", "~> 1.5"
  spec.add_runtime_dependency "nokogiri", "1.19.3"
  spec.add_runtime_dependency "parseconfig", "~> 1.1"
  spec.add_runtime_dependency "rdf-raptor", "~> 3.2"
  spec.add_runtime_dependency "rdf-vocab"
  spec.add_runtime_dependency "require_all", "~> 3.0"
  spec.add_runtime_dependency "rest-client", "~> 2.1"
  spec.add_runtime_dependency "safe_yaml"
  spec.add_runtime_dependency "triple_easy", "~> 0.1.0"
  spec.add_runtime_dependency "uri", "~> 1.1"
  spec.add_runtime_dependency "xml-simple", "~> 1.1"
  # bcrypt is someties runtime, sometimes not — move only if ftr_ruby uses it directly

  # ==================== DEVELOPMENT DEPENDENCIES (optional) ====================
  # These are useful when someone clones your gem repo to develop on it,
  # but they are NOT installed when someone does `gem install ftr_ruby`

  spec.add_development_dependency "dotenv", "~> 2.8"
  spec.add_development_dependency "irb"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  # add others like rdbg, shotgun, etc. here if you want them for gem development
end
