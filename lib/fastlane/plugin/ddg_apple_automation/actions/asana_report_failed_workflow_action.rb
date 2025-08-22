require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "asana"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"
require_relative "asana_add_comment_action"
require_relative "asana_get_user_id_for_github_handle_action"

module Fastlane
  module Actions
    class AsanaReportFailedWorkflowAction < Action
      def self.run(params)
        args = {
          workflow_name: params[:workflow_name],
          workflow_url: params[:workflow_url]
        }

        extra_collaborators = []

        if params[:commit_sha]
          args[:last_commit_url] = "https://github.com/#{Helper::GitHelper.repo_name}/commit/#{params[:commit_sha]}"
          commit_author = Helper::GitHelper.commit_author(Helper::GitHelper.repo_name, params[:commit_sha], params[:github_token])
          args[:last_commit_author_id] = Helper::AsanaHelper.get_asana_user_id_for_github_handle(commit_author)
          extra_collaborators << args[:last_commit_author_id]
        end

        unless params[:is_scheduled_release]
          args[:workflow_actor_id] = Helper::AsanaHelper.get_asana_user_id_for_github_handle(params[:github_handle])
          extra_collaborators << args[:workflow_actor_id]
        end

        extra_collaborators.uniq!

        assignee_id = Helper::AsanaHelper.extract_asana_task_assignee(params[:task_id], params[:asana_access_token])
        if extra_collaborators.include?(assignee_id)
          extra_collaborators.delete(assignee_id)
        else
          args[:assignee_id] = assignee_id
        end

        add_collaborators(extra_collaborators, params[:task_id], params[:asana_access_token])

        UI.important("Adding comment to the release task about a failed workflow run")
        AsanaAddCommentAction.run(
          task_id: params[:task_id],
          template_name: 'workflow-failed',
          template_args: args,
          asana_access_token: params[:asana_access_token]
        )
      end

      def self.add_collaborators(collaborators, task_id, asana_access_token)
        return if collaborators.empty?

        asana_client = Helper::AsanaHelper.make_asana_client(asana_access_token)
        UI.important("Adding users #{collaborators.join(', ')} as collaborators on release task's 'Automation' subtask")
        asana_client.tasks.add_followers_for_task(task_gid: task_id, followers: collaborators)
      rescue StandardError => e
        UI.user_error!("Failed to add users #{collaborators.join(', ')} as collaborators on task #{task_id}")
        Helper::DdgAppleAutomationHelper.report_error(e)
      end

      def self.description
        "Add a message to Asana Release Task notifying about a failed workflow run"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        ""
      end

      def self.details
        "Adds a comment about a failed workflow run to the Asana release task, notifying relevant people"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.is_scheduled_release,
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :task_id,
                                       description: "Asana release task ID",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :branch,
                                       description: "Branch of the repository where the workflow run was triggered",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :commit_sha,
                                       description: "Commit SHA of the workflow run",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github handle of the user who ran the workflow",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :workflow_name,
                                       description: "Name of the workflow that failed",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :workflow_url,
                                       description: "URL of the workflow that failed",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
