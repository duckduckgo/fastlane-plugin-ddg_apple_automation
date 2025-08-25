require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"

module Fastlane
  module Actions
    class FreezeReleaseBranchAction < Action
      def self.run(params)
        github_token = params[:github_token]
        platform = params[:platform] || Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        UI.message("Checking latest marketing version")
        latest_marketing_version = Helper::GitHelper.find_latest_marketing_version(github_token, params[:platform])
        UI.success("Latest marketing version: #{latest_marketing_version}")

        draft_public_release_name = "#{latest_marketing_version}+#{platform}"

        UI.message("Will freeze release branch for #{latest_marketing_version} by creating a draft public release")
        UI.message("First we'll check if #{draft_public_release_name} release exists.")

        UI.message("Checking for draft public release #{draft_public_release_name}")
        latest_public_release = Helper::GitHelper.latest_release(Helper::GitHelper.repo_name, false, platform, github_token, allow_drafts: true)
        UI.success("Latest public release (including drafts): #{latest_public_release.name}")

        if latest_public_release.name == draft_public_release_name
          UI.success("Draft public release #{draft_public_release_name} already exists. Nothing to do as the branch is already frozen.")
          return
        end

        UI.message("Creating draft public release #{draft_public_release_name}")

        begin
          other_action.set_github_release(
            repository_name: Helper::GitHelper.repo_name,
            api_bearer: github_token,
            description: "This draft release is here to indicate that the release branch is frozen.
            New internal releases on `release/#{platform}/#{latest_marketing_version}` branch cannot be created.
            If you need to bump the internal release, please manually delete this draft release.",
            name: draft_public_release_name,
            tag_name: "",
            is_draft: true,
            is_prerelease: false
          )
          UI.success("Draft public release #{draft_public_release_name} created")
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
