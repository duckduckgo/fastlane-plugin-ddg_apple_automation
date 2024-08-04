require "fastlane/action"
require_relative "../helper/ddg_release_automation_helper"

module Fastlane
  module Actions
    class AsanaExtractTaskIdAction < Action
      TASK_URL_REGEX = %r{https://app.asana.com/[0-9]/[0-9]+/([0-9]+)(:/f)?}
      ERROR_MESSAGE = "URL has incorrect format (attempted to match #{TASK_URL_REGEX})"

      def self.run(params)
        task_url = params[:task_url]

        if (match = task_url.match(TASK_URL_REGEX))
          task_id = match[1]

          if Helper.is_ci?
            Helper::GitHubActionsHelper.set_output("ASANA_TASK_ID", task_id)
          end

          task_id
        else
          UI.user_error!(ERROR_MESSAGE)
        end
      end

      def self.description
        "This action extracts the task ID from an Asana task URL"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "The task ID extracted from the Asana task URL"
      end

      def self.details
        # Optional:
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :task_url,
                                       description: "Asana task URL",
                                       optional: false,
                                       type: String),
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
