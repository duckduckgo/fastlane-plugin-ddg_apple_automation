require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "httparty"
require "json"
require "time"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/github_actions_helper"
require_relative "asana_extract_task_id_action"
require_relative "asana_extract_task_assignee_action"

module Fastlane
  module Actions
    class AsanaGetReleaseAutomationSubtaskIdAction < Action
      def self.run(params)
        task_url = params[:task_url]
        token = params[:asana_access_token]

        task_id = AsanaExtractTaskIdAction.run(task_url: task_url, asana_access_token: token)

        # Fetch release task assignee and set GHA output.
        # This is to match current GHA action behavior.
        # TODO: To be reworked for local execution.
        AsanaExtractTaskAssigneeAction.run(task_id: task_id, asana_access_token: token)

        asana_client = Asana::Client.new do |c|
          c.authentication(:access_token, token)
        end

        begin
          subtasks = asana_client.tasks.get_subtasks_for_task(task_gid: task_id, opt_fields: ["name", "created_at"])
        rescue StandardError => e
          UI.user_error!("Failed to fetch 'Automation' subtasks for task #{task_id}: #{e}")
          return
        end

        automation_subtask_id = find_oldest_automation_subtask(subtasks).gid
        Helper::GitHubActionsHelper.set_output("asana_automation_task_id", automation_subtask_id)
        automation_subtask_id
      end

      def self.description
        "This action finds 'Automation' subtask for the release task in Asana specified by the URL given as parameter"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "The 'Automation' task ID for the specified release task"
      end

      def self.details
        # Optional:
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.new(key: :task_url,
                                       description: "Asana task URL",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end

      def self.find_oldest_automation_subtask(subtasks)
        automation_subtask = subtasks
                             .find_all { |task| task.name == 'Automation' }
                             &.min_by { |task| Time.parse(task.created_at) }
        if automation_subtask.nil?
          UI.user_error!("There is no 'Automation' subtask in task: #{task_id}")
          return
        end
        automation_subtask
      end
    end
  end
end
