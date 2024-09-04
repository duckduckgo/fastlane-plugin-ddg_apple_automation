require "fastlane_core/configuration/config_item"
require "fastlane_core/ui/ui"
require "asana"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class DdgAppleAutomationHelper
      ASANA_API_URL = "https://app.asana.com/api/1.0"
      ERROR_ASANA_ACCESS_TOKEN_NOT_SET = "ASANA_ACCESS_TOKEN is not set"

      def self.load_asset_file(file)
        File.expand_path("../assets/#{file}", __dir__)
      end

      def self.asana_client
        @asana_client ||= Asana::Client.new do |c|
          c.authentication(:access_token, "ASANA_ACCESS_TOKEN")
        end
      end
    end
  end
end

module FastlaneCore
  class ConfigItem
    def self.asana_access_token
      FastlaneCore::ConfigItem.new(key: :asana_access_token,
                                   env_name: "ASANA_ACCESS_TOKEN",
                                   description: "Asana access token",
                                   optional: false,
                                   sensitive: true,
                                   type: String,
                                   verify_block: proc do |value|
                                     UI.user_error!(Fastlane::Helper::DdgAppleAutomationHelper::ERROR_ASANA_ACCESS_TOKEN_NOT_SET) if value.to_s.length == 0
                                   end)
    end
  end
end
