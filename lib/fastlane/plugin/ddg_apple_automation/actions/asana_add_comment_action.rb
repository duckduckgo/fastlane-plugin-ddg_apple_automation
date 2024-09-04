require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require_relative "../helper/ddg_apple_automation_helper"

module Fastlane
  module Actions
    class AsanaAddCommentAction < Action
      def self.run(params)
        asana_access_token = params[:asana_access_token]
        task_id = params[:task_id]
        task_url = params[:task_url]
        template_name = params[:template_name]
        comment = params[:comment]
        workflow_url = params[:workflow_url]

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
          template_content = load_template_file(template_name)
          return unless template_content

          html_text = process_template_content(template_content)
          create_story(asana_access_token, task_id, html_text: html_text)
        else
          text = "#{comment}\n\nWorkflow URL: #{workflow_url}"
          create_story(asana_access_token, task_id, text: text)
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

      def self.load_template_file(template_name)
        template_file = Helper::DdgAppleAutomationHelper.load_asset_file("asana_add_comment/templates/#{template_name}.yml")
        File.read(template_file)
      rescue StandardError
        UI.user_error!("Error: The file '#{template_name}.yml' does not exist.")
        nil
      end

      def self.create_story(asana_access_token, task_id, text: nil, html_text: nil)
        client = Asana::Client.new do |c|
          c.authentication(:access_token, asana_access_token)
        end
        begin
          if text
            response = client.stories.create_story_for_task(task_gid: task_id, text: text)
          else
            response = client.stories.create_story_for_task(task_gid: task_id, html_text: html_text)
          end
        rescue StandardError => e
          UI.user_error!("Failed to post comment: #{e}")
        end
      end

      def self.process_template_content(template_content)
        processed_content = template_content.gsub(/\$\{(\w+)\}/) { ENV.fetch($1, '') }
        processed_content.gsub(/\s*\n\s*/, ' ').strip
      end
    end
  end
end
