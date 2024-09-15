require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
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
        case platform
        when "ios"
          @constants = {
            repo_name: "duckduckgo/ios"
          }
        when "macos"
          @constants = {
            dmg_url_prefix: "https://staticcdn.duckduckgo.com/macos-desktop-browser/",
            repo_name: "duckduckgo/macos-browser"
          }
        end
      end

      def self.run(params)
        platform = params[:platform] || Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        setup_constants(platform)

        other_action.ensure_git_branch(branch: "^(:?release|hotfix)/.*$")
        Helper::GitHelper.setup_git_user

        tag_and_release_output = create_tag_and_github_release(params[:is_prerelease], params[:github_token])
        Helper::GitHubActionsHelper.set_output("tag", tag_and_release_output[:tag])

        begin
          if params[:is_prerelease]
            Helper::GitHelper.merge_branch(@constants[:repo_name], params[:branch], params[:base_branch], params[:github_elevated_permissions_token] || params[:github_token])
          else
            Helper::GitHelper.delete_branch(@constants[:repo_name], params[:branch], params[:github_token])
          end
          tag_and_release_output[:merge_or_delete_failed] = false
        rescue StandardError
          tag_and_release_output[:merge_or_delete_failed] = true
        end

        report_status(params.values.merge(tag_and_release_output))
      end

      def self.create_tag_and_github_release(is_prerelease, github_token)
        tag, promoted_tag = Helper::DdgAppleAutomationHelper.compute_tag(is_prerelease)
        tag_created = false

        begin
          other_action.add_git_tag(tag: tag)
          other_action.push_git_tags(tag: tag)
          tag_created = true
        rescue StandardError => e
          UI.important("Failed to create and push tag: #{e}")
          return {
            tag: tag,
            promoted_tag: promoted_tag,
            tag_created: tag_created
          }
        end

        begin
          client = Octokit::Client.new(access_token: github_token)
          latest_public_release = client.latest_release(@constants[:repo_name])
          UI.message("Latest public release: #{latest_public_release.tag_name}")
          UI.message("Generating #{@constants[:repo_name]} release notes for GitHub release for tag: #{tag}")

          # Octokit doesn't provide the API to generate release notes for a specific tag
          # So we need to use the GitHub API directly
          generate_release_notes = other_action.github_api(
            server_url: "https://api.github.com",
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
          tag_created: tag_created,
          latest_public_release_tag: latest_public_release.tag_name
        }
      end

      def self.report_status(params)
        template_args = {}
        template_args['tag'] = params[:tag]
        template_args['promoted_tag'] = params[:promoted_tag]
        template_args['release_url'] = "https://github.com/#{@constants[:repo_name]}/releases/tag/#{params[:tag]}"
        unless params[:tag_created]
          template_args['last_release_tag'] = params[:latest_public_release_tag]
        end
        if params[:platform] == "macos"
          dmg_version = (params[:is_prerelease] ? params[:tag] : params[:promoted_tag]).gsub('-', '.')
          template_args['dmg_url'] = "#{@constants[:repo_name]}duckduckgo-#{dmg_version}.dmg"
        end

        task_template, comment_template = setup_asana_templates(params)

        if task_template
          UI.important("Adding Asana task for release automation using #{task_template} template")
          AsanaCreateActionItemAction.run(
            asana_access_token: params[:asana_access_token],
            task_url: params[:asana_task_url],
            template_name: task_template,
            template_args: template_args,
            github_handle: params[:github_handle],
            is_scheduled_release: params[:is_scheduled_release]
          )

          if params[:is_internal_release_bump]
            AsanaCreateActionItemAction.run(
              asana_access_token: params[:asana_access_token],
              task_url: params[:asana_task_url],
              template_name: "run-publish-dmg-release",
              template_args: template_args,
              github_handle: params[:github_handle],
              is_scheduled_release: params[:is_scheduled_release]
            )
          end
        end

        AsanaLogMessageAction.run(
          asana_access_token: params[:asana_access_token],
          task_url: params[:asana_task_url],
          template_name: comment_template,
          template_args: template_args,
          github_handle: params[:github_handle],
          is_scheduled_release: params[:is_scheduled_release]
        )
      end

      def self.setup_asana_templates(params)
        if params[:merge_or_delete_failed]
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
        else
          comment_template = params[:is_prerelease] ? "internal-release-ready" : "public-release-tagged"
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
          FastlaneCore::ConfigItem.new(key: :branch,
                                       description: "Release branch name",
                                       optional: false,
                                       type: String),
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
          FastlaneCore::ConfigItem.new(key: :is_internal_release_bump,
                                       description: "Is this an internal release bump? (the subsequent internal release of the current week)",
                                       optional: true,
                                       type: Boolean,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :is_prerelease,
                                       description: "Is this a pre-release? (a.k.a. internal release)",
                                       optional: false,
                                       type: Boolean),
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
