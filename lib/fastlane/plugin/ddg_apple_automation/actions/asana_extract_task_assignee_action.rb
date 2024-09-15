require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require_relative "../helper/asana_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaExtractTaskAssigneeAction < Action
      def self.run(params)
        Helper::AsanaHelper.extract_asana_task_assignee(params[:task_id], params[:asana_access_token])
      end

      def self.description
        "This action checks Asana task assignee ID for a provided task ID"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "The assignee ID extracted from the Asana task"
      end

      def self.details
        # Optional:
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.new(key: :task_id,
                                       description: "Asana task ID",
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
