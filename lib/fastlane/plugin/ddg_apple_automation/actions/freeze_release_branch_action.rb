require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"

module Fastlane
  module Actions
    class FreezeReleaseBranchAction < Action
      def self.run(params)
        platform = params[:platform] || Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        begin
          Helper::GitHelper.freeze_release_branch(platform, params[:github_token], other_action)
        rescue StandardError => e
          UI.important("Failed to create GitHub release")
          Helper::DdgAppleAutomationHelper.report_error(e)
        end
      end

      def self.description
        "Adds a draft public release for the latest marketing version as an indicator of a frozen release branch"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        ""
      end

      def self.details
        "This action checks the latest marketing version in GitHub and creates a draft public release for it.
        If the release already exists, it does nothing."
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
