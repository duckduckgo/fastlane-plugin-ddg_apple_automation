require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "asana_extract_task_id_action"

module Fastlane
  module Actions
    class AsanaAddCommentAction < Action
      def self.run(params)
        asana_access_token = params[:asana_access_token]
        task_id = params[:task_id]
        task_url = params[:task_url]
        template_name = params[:template_name]
        comment = params[:comment]

        begin
          validate_params(task_id, task_url, comment, template_name)
        rescue ArgumentError => e
          UI.user_error!(e.message)
          return
        end

        task_id = Fastlane::Actions::AsanaExtractTaskIdAction.run(task_url: task_url) if task_url

        if template_name.to_s.empty?
          text = "#{comment}\n\nWorkflow URL: #{ENV.fetch('WORKFLOW_URL')}"
          create_story(asana_access_token, task_id, text: text)
        else
          template_file = Helper::DdgAppleAutomationHelper.path_for_asset_file("asana_add_comment/templates/#{template_name}.html")
          template_content = Helper::DdgAppleAutomationHelper.load_template_file(template_file)
          return unless template_content

          html_text = process_template_content(template_content)
          create_story(asana_access_token, task_id, html_text: html_text)
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
      The file is processed before being sent to Asana",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end

      def self.validate_params(task_id, task_url, comment, template_name)
        if task_id.to_s.empty? && task_url.to_s.empty?
          raise ArgumentError, "Both task_id and task_url cannot be empty. At least one must be provided."
        end

        if comment.to_s.empty? && template_name.to_s.empty?
          raise ArgumentError, "Both comment and template_name cannot be empty. At least one must be provided."
        end

        if comment && ENV.fetch('WORKFLOW_URL').to_s.empty?
          raise ArgumentError, "If comment is provided, workflow_url cannot be empty"
        end
      end

      def self.load_template_file(template_name)
        template_file = Helper::DdgAppleAutomationHelper.path_for_asset_file("asana_add_comment/templates/#{template_name}.html")
        File.read(template_file)
      rescue StandardError
        UI.user_error!("Error: The file '#{template_name}.html' does not exist.")
      end

      def self.create_story(asana_access_token, task_id, text: nil, html_text: nil)
        client = Asana::Client.new do |c|
          c.authentication(:access_token, asana_access_token)
        end
        begin
          if text
            client.stories.create_story_for_task(task_gid: task_id, text: text)
          else
            client.stories.create_story_for_task(task_gid: task_id, html_text: html_text)
          end
        rescue StandardError => e
          UI.user_error!("Failed to post comment: #{e}")
        end
      end

      def self.process_template_content(template_content)
        template_content.gsub(/\$\{(\w+)\}/) { ENV.fetch($1, '') }  # replace environment variables
                        .gsub(/\s+/, ' ')                           # replace multiple whitespaces with a single space
                        .gsub(/>\s+</, '><')                        # remove spaces between HTML tags
                        .strip                                      # remove leading and trailing whitespaces
                        .gsub(%r{<br\s*/?>}, "\n")                  # replace <br> tags with newlines
      end
    end
  end
end
