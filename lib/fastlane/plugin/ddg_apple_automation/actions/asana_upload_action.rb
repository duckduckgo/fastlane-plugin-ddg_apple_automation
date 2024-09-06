require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require_relative "../helper/ddg_apple_automation_helper"

module Fastlane
  module Actions
    class AsanaUploadAction < Action
      def self.run(params)
        task_id = params[:task_id]
        token = params[:asana_access_token]
        file_name = params[:file_name]

        asana_client = Asana::Client.new do |c|
          c.authentication(:access_token, token)
        end

        begin
          asana_client.tasks.find_by_id(task_id).attach(filename: file_name, mime: "application/octet-stream")
        rescue StandardError => e
          UI.user_error!("Failed to upload file to Asana task: #{e}")
          return
        end
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
