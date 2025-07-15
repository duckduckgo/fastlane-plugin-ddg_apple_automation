require "fastlane/action"
require "fastlane_core/configuration/config_item"
require_relative "../helper/ddg_apple_automation_helper"

module Fastlane
  module Actions
    class CalculateNextBuildNumberAction < Action
      def self.run(params)
        Helper::GitHelper.setup_git_user
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        options = params.values
        Helper::DdgAppleAutomationHelper.calculate_next_build_number(options[:platform], options, options[:config], options[:bundle_id], other_action)
      end

      def self.description
        "Calculates the next build number for a given configuration and bundle ID"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "The next build number"
      end

      def self.details
        "This action calculates the next build number for a given configuration and bundle ID."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.string(key: :config,
                                          description: "The configuration to use for the build number",
                                          default_value: "release"),
          FastlaneCore::ConfigItem.string(key: :bundle_id,
                                          description: "The bundle ID to use for the build number",
                                          default_value: nil)
        ]
      end

      def self.is_supported?(platform)
        platform == "macos"
      end
    end
  end
end
