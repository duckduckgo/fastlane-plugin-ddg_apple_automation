require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaExtractTaskAssigneeAction < Action
      def self.run(params)
        task_id = params[:task_id]
        token = params[:asana_access_token]

        client = Asana::Client.new do |c|
          c.authentication(:access_token, token)
        end

        begin
          task = client.tasks.get_task(task_gid: task_id)
        rescue StandardError => e
          UI.user_error!("Failed to fetch task assignee: #{e}")
          return
        end

        assignee_id = task.assignee.gid
        Helper::GitHubActionsHelper.set_output("asana_assignee_id", assignee_id)
        assignee_id
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
