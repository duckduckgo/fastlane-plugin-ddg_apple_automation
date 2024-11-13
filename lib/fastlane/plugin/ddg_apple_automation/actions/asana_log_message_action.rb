require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require_relative "../helper/asana_helper"
require_relative "asana_add_comment_action"
require_relative "asana_get_user_id_for_github_handle_action"

module Fastlane
  module Actions
    class AsanaLogMessageAction < Action
      def self.run(params)
        token = params[:asana_access_token]
        task_url = params[:task_url]
        template_name = params[:template_name]
        comment = params[:comment]
        args = (params[:template_args] || {}).merge(Hash(ENV).transform_keys { |key| key.downcase.gsub('-', '_') })

        automation_task_id = Helper::AsanaHelper.get_release_automation_subtask_id(task_url, token)
        args[:automation_task_id] = automation_task_id
        asana_user_id = find_asana_user_id(params)
        args[:assignee_id] = asana_user_id

        asana_client = Asana::Client.new do |c|
          c.authentication(:access_token, token)
          c.default_headers("Asana-Enable" => "new_goal_memberships,new_user_task_lists")
        end

        begin
          UI.important("Adding user #{asana_user_id} as collaborator on release task's 'Automation' subtask")
          asana_client.tasks.add_followers_for_task(task_gid: automation_task_id, followers: [asana_user_id])
        rescue StandardError => e
          UI.user_error!("Failed to add user #{asana_user_id} as collaborator on task #{automation_task_id}: #{e}")
        end

        if template_name.to_s.empty?
          UI.important("Adding comment to release task's 'Automation' subtask")
        else
          UI.important("Adding comment to release task's 'Automation' subtask using #{template_name} template")
        end
        AsanaAddCommentAction.run(
          task_id: automation_task_id,
          comment: comment,
          template_name: template_name,
          template_args: args,
          asana_access_token: token
        )
      end

      def self.find_asana_user_id(params)
        if params[:is_scheduled_release]
          task_id = Helper::AsanaHelper.extract_asana_task_id(params[:task_url])
          Helper::AsanaHelper.extract_asana_task_assignee(task_id, params[:asana_access_token])
        else
          if params[:github_handle].to_s.empty?
            UI.user_error!("Github handle cannot be empty for manual release")
            return
          end
          Helper::AsanaHelper.get_asana_user_id_for_github_handle(params[:github_handle])
        end
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
    end
  end
end
