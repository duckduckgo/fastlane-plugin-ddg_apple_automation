require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class BumpBuildNumberAction < Action
      def self.run(params)
        Helper::GitHelper.setup_git_user
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        options = params.values
        Helper::DdgAppleAutomationHelper.increment_build_number(options[:platform], options, other_action)
      end

      def self.description
        "Prepares a subsequent internal release"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "The newly created release task ID"
      end

      def self.details
        "This action increments the project build number and pushes the changes to the remote repository."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.platform
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
