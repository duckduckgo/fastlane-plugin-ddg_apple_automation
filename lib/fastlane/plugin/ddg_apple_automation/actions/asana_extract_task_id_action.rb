require "fastlane/action"
require "fastlane_core/configuration/config_item"
require_relative "../helper/asana_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class AsanaExtractTaskIdAction < Action
      def self.run(params)
        Helper::AsanaHelper.extract_asana_task_id(params[:task_url])
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
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
