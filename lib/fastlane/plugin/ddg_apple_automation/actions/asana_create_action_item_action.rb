require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require "erb"
require "yaml"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/github_actions_helper"
require_relative "asana_add_comment_action"
require_relative "asana_get_user_id_for_github_handle_action"

module Fastlane
  module Actions
    class AsanaCreateActionItemAction < Action
      def self.run(params)
        token = params[:asana_access_token]
        task_url = params[:task_url]
        args = (params[:template_args] || {}).merge(Hash(ENV).transform_keys(&:downcase))

        task_id = Helper::AsanaHelper.extract_asana_task_id(task_url)
        automation_subtask_id = Helper::AsanaHelper.get_release_automation_subtask_id(task_url, token)
        assignee_id = fetch_assignee_id(
          task_id: task_id,
          github_handle: params[:github_handle],
          asana_access_token: token,
          is_scheduled_release: params[:is_scheduled_release]
        )

        Helper::GitHubActionsHelper.set_output("asana_assignee_id", assignee_id)

        if (template_name = params[:template_name])
          raw_name, raw_html_notes = process_yaml_template(template_name, args)

          task_name = Helper::AsanaHelper.sanitize_asana_html_notes(raw_name)
          html_notes = Helper::AsanaHelper.sanitize_asana_html_notes(raw_html_notes)
        else
          task_name = params[:task_name]
          html_notes = params[:html_notes]
        end

        begin
          subtask = create_subtask(
            token: token,
            task_id: automation_subtask_id,
            assignee_id: assignee_id,
            task_name: task_name,
            notes: params[:notes],
            html_notes: html_notes
          )
        rescue StandardError => e
          UI.user_error!("Failed to create subtask for task: #{e}")
        end

        Helper::GitHubActionsHelper.set_output("asana_new_task_id", subtask.gid) if subtask&.gid
      end

      def self.fetch_assignee_id(task_id:, github_handle:, asana_access_token:, is_scheduled_release:)
        if is_scheduled_release
          Helper::AsanaHelper.extract_asana_task_assignee(task_id, asana_access_token)
        else
          if github_handle.to_s.empty?
            UI.user_error!("Github handle cannot be empty for manual release")
            return
          end
          Helper::AsanaHelper.get_asana_user_id_for_github_handle(github_handle)
        end
      end

      def self.process_yaml_template(template_name, args)
        template_file = Helper::DdgAppleAutomationHelper.path_for_asset_file("asana_create_action_item/templates/#{template_name}.yml.erb")
        yaml = Helper::DdgAppleAutomationHelper.process_erb_template(template_file, args)
        task_data = YAML.safe_load(yaml)
        return task_data["name"], task_data["html_notes"]
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
          FastlaneCore::ConfigItem.new(key: :template_args,
                                       description: "Template arguments. For backward compatibility, environment variables are added to this hash",
                                       optional: true,
                                       type: Hash,
                                       default_value: {}),
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

      def self.create_subtask(token:, task_id:, assignee_id:, task_name:, notes: nil, html_notes: nil)
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
