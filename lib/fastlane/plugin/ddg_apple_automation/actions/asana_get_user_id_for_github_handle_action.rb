require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "yaml"
require_relative "../helper/asana_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaGetUserIdForGithubHandleAction < Action
      def self.run(params)
        Helper::AsanaHelper.get_asana_user_id_for_github_handle(params[:github_handle])
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
