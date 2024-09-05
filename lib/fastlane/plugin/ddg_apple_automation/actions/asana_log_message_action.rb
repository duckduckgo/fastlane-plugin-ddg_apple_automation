require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "asana_add_comment_action"
require_relative "asana_get_release_automation_subtask_id_action"
require_relative "asana_get_user_id_for_github_handle_action"

module Fastlane
  module Actions
    class AsanaLogMessageAction < Action
      def self.run(params)
        asana_access_token = params[:asana_access_token]
        task_url = params[:task_url]
        template_name = params[:template_name]
        comment = params[:comment]
        is_scheduled_release = params[:is_scheduled_release] || true
        github_handle = params[:github_handle]

        automation_subtask_id = AsanaGetReleaseAutomationSubtaskIdAction.run(task_url: task_url, asana_access_token: token)

        if is_scheduled_release
          task_id = AsanaExtractTaskIdAction.run(task_url: task_url)
          assignee_id = AsanaExtractTaskAssigneeAction.run(task_id: task_id, asana_access_token: token)
        else
          assignee_id = AsanaGetUserIdForGithubHandleAction.run(github_handle: github_handle, asana_access_token: token)
        end

        asana_client = Asana::Client.new do |c|
          c.authentication(:access_token, asana_access_token)
        end

        begin
          asana_client.tasks.add_followers_for_task(task_gid: task_id, followers: [assignee_id])
        rescue StandardError => e
          UI.user_error!("Failed to add a collaborator to the release task: #{e}")
        end

        AsanaAddCommentAction.run(task_id: automation_subtask_id, comment: comment, template_name: template_name, asana_access_token: token)
      end

      def self.description
        "Add a Message to Asana Release Automation Task"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        ""
      end

      def self.details
        "Adds a comment about release progress to the Asana release task's 'Automation' subtask"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.new(key: :task_url,
                                       description: "Asana release task URL",
                                       optional: false,
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
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github user handle",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :is_scheduled_release,
                                       description: "Indicates whether the release was scheduled or started manually",
                                       optional: true,
                                       type: Boolean)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
