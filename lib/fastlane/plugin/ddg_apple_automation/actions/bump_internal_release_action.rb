require "fastlane/action"
require "fastlane_core/configuration/config_item"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"

module Fastlane
  module Actions
    class BumpInternalReleaseAction < Action
      def self.run(params)
        Helper::GitHelper.setup_git_user
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        Helper::DdgAppleAutomationHelper.bump_version_and_build_number(params[:platform], params, other_action)
      end

      def self.description
        "Bumps the project build number (and optionally sets a new version) and pushes the changes to the remote repository"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        ""
      end

      def self.details
        # Optional:
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github user handle",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :validation_section_id,
                                       description: "Validation section ID",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
