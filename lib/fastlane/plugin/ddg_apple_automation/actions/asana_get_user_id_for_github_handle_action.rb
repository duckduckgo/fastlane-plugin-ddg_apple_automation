require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "yaml"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaGetUserIdForGithubHandleAction < Action
      def self.run(params)
        github_handle = params[:github_handle]

        mapping_file = File.expand_path('../assets/github-asana-user-id-mapping.yml', __dir__)
        user_mapping = YAML.load_file(mapping_file)
        asana_user_id = user_mapping[github_handle]

        if asana_user_id.nil? || asana_user_id.to_s.empty?
          UI.warning("Asana User ID not found for GitHub handle: #{github_handle}")
        else
          Helper::GitHubActionsHelper.set_output("asana_user_id", asana_user_id)
          asana_user_id
        end
      end

      def self.description
        "This action returns Asana user ID that matches GitHub user handle"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "User ID that matches GitHub user handle"
      end

      def self.details
        # Optional:
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github user handle",
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
