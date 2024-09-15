require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require "erb"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/asana_helper"

module Fastlane
  module Actions
    class AsanaAddCommentAction < Action
      def self.run(params)
        asana_access_token = params[:asana_access_token]
        task_id = params[:task_id]
        task_url = params[:task_url]
        template_name = params[:template_name]
        comment = params[:comment]
        args = (params[:template_args] || {}).merge(Hash(ENV).transform_keys { |key| key.downcase.gsub('-', '_') })

        workflow_url = args["workflow_url"]

        begin
          validate_params(task_id, task_url, comment, template_name, workflow_url)
        rescue ArgumentError => e
          UI.user_error!(e.message)
          return
        end

        task_id = Helper::AsanaHelper.extract_asana_task_id(task_url) if task_url

        if template_name.to_s.empty?
          text = "#{comment}\n\nWorkflow URL: #{workflow_url}"
          create_story(asana_access_token, task_id, text: text)
        else
          html_text = process_template(template_name, args)
          sanitized_html_text = Helper::AsanaHelper.sanitize_asana_html_notes(html_text)
          create_story(asana_access_token, task_id, html_text: sanitized_html_text)
        end
      end

      def self.process_template(template_name, args)
        template_file = Helper::DdgAppleAutomationHelper.path_for_asset_file("asana_add_comment/templates/#{template_name}.html.erb")
        Helper::DdgAppleAutomationHelper.process_erb_template(template_file, args)
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
          FastlaneCore::ConfigItem.new(key: :template_args,
                                       description: "Template arguments. For backward compatibility, environment variables are added to this hash",
                                       optional: true,
                                       type: Hash,
                                       default_value: {})
        ]
      end

      def self.is_supported?(platform)
        true
      end

      def self.validate_params(task_id, task_url, comment, template_name, workflow_url)
        if task_id.to_s.empty? && task_url.to_s.empty?
          raise ArgumentError, "Both task_id and task_url cannot be empty. At least one must be provided."
        end

        if comment.to_s.empty? && template_name.to_s.empty?
          raise ArgumentError, "Both comment and template_name cannot be empty. At least one must be provided."
        end

        if comment && workflow_url.to_s.empty?
          raise ArgumentError, "If comment is provided, workflow_url cannot be empty"
        end
      end

      def self.create_story(asana_access_token, task_id, text: nil, html_text: nil)
        client = Asana::Client.new do |c|
          c.authentication(:access_token, asana_access_token)
          c.default_headers["Asana-Enable"] = "new_goal_memberships"
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
    end
  end
end
