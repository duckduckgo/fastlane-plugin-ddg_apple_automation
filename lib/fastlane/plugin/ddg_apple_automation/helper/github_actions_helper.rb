require "fastlane/action"
require "fastlane_core/ui/ui"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class GitHubActionsHelper
      def self.set_output(key, value)
        return unless Helper.is_ci?

        if key.to_s.length == 0
          UI.user_error!("Key cannot be empty")
        elsif value.to_s.length > 0
          Action.sh("echo '#{key}=#{value}' >> #{ENV.fetch('GITHUB_OUTPUT', '/dev/null')}")
        end
      end
    end
  end
end
