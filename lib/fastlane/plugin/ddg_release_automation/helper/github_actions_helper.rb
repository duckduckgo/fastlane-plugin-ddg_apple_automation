require "fastlane_core/ui/ui"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class GitHubActionsHelper
      def self.set_output(key, value)
        Action.sh("echo '#{key}=#{value}' >> #{ENV.fetch("GITHUB_OUTPUT", "/dev/null")}")
      end
    end
  end
end
