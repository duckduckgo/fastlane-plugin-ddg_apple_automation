require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "time"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaGetReleaseAutomationSubtaskIdAction < Action
      def self.run(params)
        Helper::AsanaHelper.get_release_automation_subtask_id(params[:task_url], params[:asana_access_token])
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
