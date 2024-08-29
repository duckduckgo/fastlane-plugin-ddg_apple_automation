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
        AsanaExtractTaskAssigneeAction.run(task_id: task_id, asana_access_token: token)

        url = Helper::DdgAppleAutomationHelper::ASANA_API_URL + "/tasks/#{task_id}/subtasks?opt_fields=name,created_at"
        response = HTTParty.get(url, headers: { 'Authorization' => "Bearer #{token}" })

        if response.success?
          data = response.parsed_response['data']
          automation_subtask_id = data
                                  .find_all { |hash| hash['name'] == 'Automation' }
                                  &.min_by { |x| Time.parse(x['created_at']) } # Get the oldest 'Automation' subtask
                                  &.dig('gid')
          Helper::GitHubActionsHelper.set_output("asana_automation_task_id", automation_subtask_id)
          automation_subtask_id
        else
          UI.user_error!("Failed to fetch 'Automation' subtask: (#{response.code} #{response.message})")
        end
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
    end
  end
end
