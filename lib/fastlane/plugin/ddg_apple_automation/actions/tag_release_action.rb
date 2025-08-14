require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require "date"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"
require_relative "asana_extract_task_id_action"
require_relative "asana_log_message_action"
require_relative "asana_create_action_item_action"

module Fastlane
  module Actions
    class TagReleaseAction < Action
      @constants = {}

      def self.setup_constants(platform)
        @constants = {
          repo_name: "duckduckgo/apple-browsers"
        }
        if platform == "macos"
          @constants[:dmg_url_prefix] = "https://staticcdn.duckduckgo.com/macos-desktop-browser/"
        end
      end

      def self.run(params)
        platform = params[:platform] || Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        other_action.ensure_git_branch(branch: "^(release|hotfix)/#{platform}/.+$")
        Helper::GitHelper.setup_git_user

        setup_constants(platform)

        unless assert_branch_tagged_before_public_release(params)
          UI.user_error!("Skipping release because release branch's HEAD is not tagged.")
          Helper::GitHubActionsHelper.set_output("stop_workflow", true)
          return
        end

        if params[:ignore_untagged_commits]
          begin
            # merge the branch (not the tag) to the base branch first to have untagged commits in the base branch
            Helper::GitHelper.merge_branch(@constants[:repo_name], params[:branch], params[:base_branch], params[:github_elevated_permissions_token] || params[:github_token])
          rescue StandardError
            report_merge_release_branch_before_deleting_failed(params)
            UI.user_error!("Merging release branch to base branch failed. Cannot proceed with the public release. Please merge manually and run the workflow again.")
            return
          end
        end

        tag_and_release_output = create_tag_and_github_release(params[:is_prerelease], platform, params[:github_token])
        Helper::GitHubActionsHelper.set_output("tag", tag_and_release_output[:tag])

        begin
          merge_or_delete_branch(params.values.merge(tag: tag_and_release_output[:tag]))
          tag_and_release_output[:merge_or_delete_successful] = true
        rescue StandardError
          tag_and_release_output[:merge_or_delete_successful] = false
        end

        report_status(params.values.merge(tag_and_release_output))
      end

      def self.assert_branch_tagged_before_public_release(params)
        return true if params[:is_prerelease]

        untagged_commit_sha = Helper::GitHelper.untagged_commit_sha(other_action.git_branch, params[:platform])
        if untagged_commit_sha
          if params[:ignore_untagged_commits]
            UI.important("Untagged commits found but ignoring them because ignore_untagged_commits is true.")
            UI.important("Release branch will be merged to base branch and then deleted. Untagged commits will not be included in this release.")
            return true
          end
          report_untagged_release_branch(params.values.merge(untagged_commit_sha: untagged_commit_sha))
          return false
        end
        true
      end

      def self.create_tag_and_github_release(is_prerelease, platform, github_token)
        tag, promoted_tag = Helper::DdgAppleAutomationHelper.compute_tag(is_prerelease, platform)

        begin
          # For public release, always tag the promoted tag. This is to ensure that if extra commits
          # were added to the release branch, the tag will still be the same as the promoted tag.
          if promoted_tag
            other_action.add_git_tag(tag: tag, commit: Helper::GitHelper.commit_sha_for_tag(promoted_tag))
          else
            other_action.add_git_tag(tag: tag)
          end
          other_action.push_git_tags(tag: tag)
        rescue StandardError => e
          UI.important("Failed to create and push tag: #{e}")
          return {
            tag: tag,
            promoted_tag: promoted_tag,
            tag_created: false
          }
        end

        begin
          latest_public_release = Helper::GitHelper.latest_release(@constants[:repo_name], false, platform, github_token)

          UI.message("Latest public release: #{latest_public_release.tag_name}")
          UI.message("Generating #{@constants[:repo_name]} release notes for GitHub release for tag: #{tag}")

          # Octokit doesn't provide the API to generate release notes for a specific tag
          # So we need to use the GitHub API directly
          generate_release_notes = other_action.github_api(
            api_bearer: github_token,
            http_method: "POST",
            path: "/repos/#{@constants[:repo_name]}/releases/generate-notes",
            body: {
              tag_name: tag,
              previous_tag_name: latest_public_release.tag_name
            }
          )

          release_notes = JSON.parse(generate_release_notes[:body])

          other_action.set_github_release(
            repository_name: @constants[:repo_name],
            api_bearer: github_token,
            tag_name: tag,
            name: release_notes&.dig('name'),
            description: release_notes&.dig('body'),
            is_prerelease: is_prerelease
          )
        rescue StandardError => e
          UI.important("Failed to create GitHub release: #{e}")
        end

        {
          tag: tag,
          promoted_tag: promoted_tag,
          tag_created: true,
          latest_public_release_tag: latest_public_release&.tag_name
        }
      end

      def self.merge_or_delete_branch(params)
        if params[:is_prerelease]
          # we actually merge the tag, not the branch
          Helper::GitHelper.merge_branch(@constants[:repo_name], params[:tag], params[:base_branch], params[:github_elevated_permissions_token] || params[:github_token])
        else
          branch = other_action.git_branch
          Helper::GitHelper.delete_branch(@constants[:repo_name], branch, params[:github_elevated_permissions_token] || params[:github_token])
        end
      end

      def self.report_merge_release_branch_before_deleting_failed(params)
        return
      end

      def self.report_untagged_release_branch(params)
        template_name = "public-release-tag-failed-untagged-commits"
        tag, promoted_tag = Helper::DdgAppleAutomationHelper.compute_tag(params[:is_prerelease], params[:platform])
        template_args = self.template_arguments(params).merge(
          untagged_commit_url: "https://github.com/#{@constants[:repo_name]}/commit/#{params[:untagged_commit_sha]}",
          tag: tag,
          promoted_tag: promoted_tag
        )

        create_action_item(params, template_name, template_args)
        log_message(params, template_name, template_args)
      end

      def self.report_status(params)
        template_args = self.template_arguments(params)
        task_template, comment_template = setup_asana_templates(params)

        if task_template
          create_action_item(params, task_template, template_args)
        end

        log_message(params, comment_template, template_args)
      end

      def self.create_action_item(params, template_name, template_args)
        UI.important("Adding Asana task for release automation using #{task_template} template")
        template_args['task_id'] = AsanaCreateActionItemAction.run(
          asana_access_token: params[:asana_access_token],
          task_url: params[:asana_task_url],
          template_name: template_name,
          template_args: template_args,
          github_handle: params[:github_handle],
          is_scheduled_release: params[:is_scheduled_release],
          due_date: Date.today.strftime('%Y-%m-%d')
        )
      end

      def self.log_message(params, template_name, template_args)
        AsanaLogMessageAction.run(
          asana_access_token: params[:asana_access_token],
          task_url: params[:asana_task_url],
          template_name: template_name,
          template_args: template_args,
          github_handle: params[:github_handle],
          is_scheduled_release: params[:is_scheduled_release]
        )
      end

      def self.template_arguments(params)
        template_args = {}
        template_args['base_branch'] = params[:base_branch]
        template_args['branch'] = other_action.git_branch
        template_args['tag'] = params[:tag]
        template_args['promoted_tag'] = params[:promoted_tag]
        template_args['release_url'] = "https://github.com/#{@constants[:repo_name]}/releases/tag/#{params[:tag]}"
        unless params[:tag_created]
          template_args['last_release_tag'] = params[:latest_public_release_tag]
        end
        if params[:platform] == "macos"
          dmg_version = (params[:is_prerelease] ? params[:tag]&.sub(/\+.*/, '')&.tr('-', '.') : params[:promoted_tag])&.sub(/\+.*/, '')&.tr('-', '.')
          template_args['dmg_url'] = "#{@constants[:dmg_url_prefix]}duckduckgo-#{dmg_version}.dmg"
        end
        template_args
      end

      def self.setup_asana_templates(params)
        if params[:merge_or_delete_successful]
          comment_template = params[:is_prerelease] ? "internal-release-ready" : "public-release-tagged"
        else
          case [params[:tag_created], params[:is_prerelease]]
          when [true, true]
            task_template = "merge-failed"
            comment_template = "internal-release-ready-merge-failed"
          when [true, false]
            task_template = "delete-branch-failed"
            comment_template = "public-release-tagged-delete-branch-failed"
          when [false, true]
            task_template = "internal-release-tag-failed"
            comment_template = "internal-release-ready-tag-failed"
          when [false, false]
            task_template = "public-release-tag-failed"
            comment_template = "public-release-tag-failed"
          end
        end

        return task_template, comment_template
      end

      def self.description
        "Tags the release in GitHub and merges release branch to main"
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
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.is_scheduled_release,
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :asana_task_url,
                                       description: "Asana release task URL",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :base_branch,
                                       description: "Base branch name (defaults to main, only override for testing)",
                                       optional: true,
                                       type: String,
                                       default_value: "main"),
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github user handle",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_elevated_permissions_token,
                                       env_name: "GITHUB_ELEVATED_PERMISSIONS_TOKEN",
                                       description: "GitHub token with elevated permissions (allowing to bypass branch protections)",
                                       optional: true,
                                       sensitive: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :ignore_untagged_commits,
                                       description: "For public release, ignore untagged commits on the release branch",
                                       optional: true,
                                       type: Boolean,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :is_internal_release_bump,
                                       description: "Is this an internal release bump? (the subsequent internal release of the current week)",
                                       optional: true,
                                       type: Boolean,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :is_prerelease,
                                       description: "Is this a pre-release? (a.k.a. internal release)",
                                       optional: false,
                                       type: Boolean)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
