require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class DdgAppleAutomationHelper
      # class methods that you define here become available in your action
      # as `Helper::DdgAppleAutomationHelper.your_method`
      #

      ASANA_API_URL = "https://app.asana.com/api/1.0"

      def self.show_message
        UI.message("Hello from the ddg_apple_automation plugin helper!")
      end

      def self.fetch_asana_token
        ENV.fetch("ASANA_ACCESS_TOKEN")
      rescue KeyError
        UI.user_error!("ASANA_ACCESS_TOKEN is not set")
      end
    end
  end
end
