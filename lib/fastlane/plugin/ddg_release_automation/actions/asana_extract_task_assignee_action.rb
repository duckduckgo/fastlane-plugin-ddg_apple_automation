require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "httparty"
require "json"
require_relative "../helper/ddg_release_automation_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaExtractTaskAssigneeAction < Action
      def self.run(params)
        task_id = params[:task_id]
        token = Helper::DdgReleaseAutomationHelper.fetch_asana_token
        url = Helper::DdgReleaseAutomationHelper::ASANA_API_URL + "/tasks/#{task_id}?opt_fields=assignee"

        response = HTTParty.get(url, headers: { 'Authorization' => "Bearer #{token}" })

        if response.success?
          assignee_id = response.parsed_response.dig('data', 'assignee', 'gid')
        else
          UI.user_error!("Failed to fetch task assignee: (#{response.code} #{response.message})")
        end

        if Helper.is_ci?
          Helper::GitHubActionsHelper.set_output("asana_assignee_id", assignee_id)
        end

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
