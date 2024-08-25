lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/ddg_apple_automation/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-ddg_apple_automation'
  spec.version       = Fastlane::DdgAppleAutomation::VERSION
  spec.author        = 'DuckDuckGo'
  spec.email         = 'ios@duckduckgo.com'

  spec.summary       = 'This plugin contains actions used for workflow automation in DuckDuckGo Apple repositories'
  spec.homepage      = "https://github.com/duckduckgo/fastlane-plugin-ddg_apple_automation"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 2.6'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  # spec.add_dependency 'your-dependency', '~> 1.0.0'
end
