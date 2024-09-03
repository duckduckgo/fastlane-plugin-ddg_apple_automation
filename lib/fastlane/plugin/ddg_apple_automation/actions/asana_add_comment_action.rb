require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "httparty"
require "json"
require "Base64"
require_relative "../helper/ddg_apple_automation_helper"

module Fastlane
  module Actions
    class AsanaAddCommentAction < Action
      def self.run(params)
        token = params[:asana_access_token]
        task_id = params[:task_id]
        task_url = params[:task_url]
        template_name = params[:template_name]
        comment = params[:comment]
        workflow_url = params[:workflow_url]

        url = Helper::DdgAppleAutomationHelper::ASANA_API_URL + "/tasks/#{task_id}/stories"

        if task_id.nil? && task_url.nil?
          UI.user_error!("Both task_id and task_url cannot be nil. At least one must be provided.")
          return
        end

        if comment.nil? && template_name.nil?
          UI.user_error!("Both comment and template_name cannot be nil. At least one must be provided.")
          return
        end

        if comment && workflow_url.nil?
          UI.user_error!("If comment is provided, workflow_url cannot be nil")
          return
        end

        if task_url
          task_id = Fastlane::Actions::AsanaExtractTaskIdAction.run(task_url: task_url)
        end

        if template_name
          template_file = File.expand_path("../assets/asana_add_comment/templates/#{template_name}.yml", __dir__)
          begin
            template_content = File.read(template_file)
          rescue StandardError
            UI.user_error!("Error: The file '#{template_name}.yml' does not exist.")
            return
          end
          processed_content = process_template_content(template_content)
        else
          processed_content = process_comment(comment, workflow_url)
        end

        base64_encoded_payload = convert_to_json_and_encode_Base64(processed_content)

        response = HTTParty.post(
          url,
          headers: {
            'Authorization' => "Bearer #{token}",
            'Content-Type' => 'application/json'
            },
          body: base64_encoded_payload
        )

        unless response.success?
          UI.user_error!("Failed to post comment: (#{response.code} #{response.message})")
        end
      end

      def self.description
        "Adds a comment to the Asana task"
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
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :task_url,
                                       description: "Asana task URL",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :comment,
                                       description: "Comment to add to the Asana task",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :template_name,
                                       description: "Name of a template file (without extension) for the comment. Templates can be found in assets/asana_add_comment/templates subdirectory.
      The file is processed before being sent to Asana.",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :workflow_url,
                                       description: "Workflow URL to include in the comment",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end

      def self.process_template_content(template_content)
        processed_content = template_content.gsub(/\$\{(\w+)\}/) { ENV.fetch($1, '') }
        processed_content.gsub(/\s*\n\s*/, ' ').strip
      end

      def self.process_comment(comment, workflow_url)
        payload_hash = {
          'data' => {
            'text' => "#{comment}\n\nWorkflow URL: #{workflow_url}"
          }
        }
      end

      def self.convert_to_json_and_encode_Base64(data)
        json_payload = data.to_json
        payload_base64 = Base64.strict_encode64(json_payload)
      end
    end
  end
end
