require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require "yaml"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/github_actions_helper"
require_relative "asana_add_comment_action"
require_relative "asana_get_release_automation_subtask_id_action"
require_relative "asana_get_user_id_for_github_handle_action"
require_relative "asana_extract_task_id_action"
require_relative "asana_extract_task_assignee_action"

module Fastlane
  module Actions
    class AsanaCreateActionItemAction < Action
      def self.run(params)
        token = params[:asana_access_token]
        task_url = params[:task_url]
        task_name = params[:task_name]
        notes = params[:notes]
        html_notes = params[:html_notes]
        template_name = params[:template_name]
        is_scheduled_release = params[:is_scheduled_release]
        github_handle = params[:github_handle]

        task_id = AsanaExtractTaskIdAction.run(task_url: task_url)
        automation_subtask_id = AsanaGetReleaseAutomationSubtaskIdAction.run(task_url: task_url, asana_access_token: token)
        if is_scheduled_release
          assignee_id = AsanaExtractTaskAssigneeAction.run(task_id: task_id, asana_access_token: token)
        else
          if github_handle.to_s.empty?
            UI.user_error!("Github handle cannot be empty for manual release")
            return
          end
          assignee_id = AsanaGetUserIdForGithubHandleAction.run(github_handle: github_handle, asana_access_token: token)
        end

        Helper::GitHubActionsHelper.set_output("asana_assignee_id", assignee_id)

        if template_name
          template_file = Helper::DdgAppleAutomationHelper.path_for_asset_file("asana_create_action_item/templates/#{template_name}.yml")
          template_content = YAML.safe_load(Helper::DdgAppleAutomationHelper.load_file(template_file))
          task_name = Helper::DdgAppleAutomationHelper.sanitize_html_and_replace_env_vars(template_content["name"])
          html_notes = Helper::DdgAppleAutomationHelper.sanitize_html_and_replace_env_vars(template_content["html_notes"])
        end

        begin
          subtask = create_subtask(
            task_id: automation_subtask_id,
            assignee_id: assignee_id,
            task_name: task_name,
            notes: notes,
            html_notes: html_notes
          )
        rescue StandardError => e
          UI.user_error!("Failed to create subtask for task: #{e}")
        end

        Helper::GitHubActionsHelper.set_output("asana_new_task_id", subtask.gid) if subtask&.gid
      end

      def self.description
        "Add a subtask to Asana Release Automation Task"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        ""
      end

      def self.details
        "Adds a task with an action item to the Asana release task's 'Automation' subtask"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.new(key: :task_url,
                                       description: "Asana release task URL",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :task_name,
                                       description: "Task name",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :notes,
                                       description: "Task notes",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :html_notes,
                                       description: "Task HTML notes",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :template_name,
                                       description: "Name of a template file (without extension) for the task content. Templates can be found in assets/asana_create_action_item/templates subdirectory.
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
                                       type: Boolean,
                                       default_value: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end

      def self.create_subtask(task_id:, assignee_id:, task_name:, notes: nil, html_notes: nil)
        subtask_options = {
          task_gid: task_id,
          assignee: assignee_id,
          name: task_name
        }
        subtask_options[:notes] = notes unless notes.nil?
        subtask_options[:html_notes] = html_notes unless html_notes.nil?

        asana_client = Asana::Client.new do |c|
          c.authentication(:access_token, token)
        end
        asana_client.tasks.create_subtask_for_task(**subtask_options)
      end
    end
  end
end
