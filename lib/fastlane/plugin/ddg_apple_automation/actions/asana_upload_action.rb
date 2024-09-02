require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "httparty"
require_relative "../helper/ddg_apple_automation_helper"

module Fastlane
  module Actions
    class AsanaUploadAction < Action
      def self.run(params)
        task_id = params[:task_id]
        token = params[:asana_access_token]
        file_name = params[:file_name]

        begin
          file = File.open(file_name)
          url = Helper::DdgAppleAutomationHelper::ASANA_API_URL + "/tasks/#{task_id}/attachments"
          response = HTTParty.post(url,
                                   headers: { 'Authorization' => "Bearer #{token}" },
                                   body: { file: file })

          unless response.success?
            UI.user_error!("Failed to upload file to Asana task: (#{response.code} #{response.message})")
          end
        rescue Errno::ENOENT
          UI.user_error!("Failed to open file: #{file_name}")
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
                                       description: "Path to the file that will be uploaded",
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
