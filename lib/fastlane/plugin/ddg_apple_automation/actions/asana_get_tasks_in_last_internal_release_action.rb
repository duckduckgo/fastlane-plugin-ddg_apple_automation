require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "time"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaGetTasksInLastInternalReleaseAction < Action
      def self.run(params)
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        Helper::AsanaHelper.get_tasks_in_last_internal_release(params[:platform], params[:github_token])
      end

      def self.description
        "This action finds the last release in Github and returns the tasks included in it"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "List of asana formatted task ids"
      end

      def self.details
        # Optional:
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.asana_access_token
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
