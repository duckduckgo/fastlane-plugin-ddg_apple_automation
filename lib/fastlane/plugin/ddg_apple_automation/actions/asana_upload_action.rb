require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require_relative "../helper/asana_helper"

module Fastlane
  module Actions
    class AsanaUploadAction < Action
      def self.run(params)
        Helper::AsanaHelper.upload_file_to_asana_task(params[:task_id], params[:file_name], params[:asana_access_token])
      end

      def self.description
        "Uploads a file to an Asana task"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        ""
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
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :file_name,
                                       description: "Path to a file that will be uploaded",
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
