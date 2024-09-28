require "fastlane/action"
require "fastlane_core/configuration/config_item"
require "octokit"
require_relative "../helper/asana_helper"
require_relative "../helper/ddg_apple_automation_helper"
require_relative "../helper/git_helper"
require_relative "../helper/github_actions_helper"

module Fastlane
  module Actions
    class StartNewReleaseAction < Action
      @constants = {}

      def self.setup_constants(platform)
        case platform
        when "ios"
          @constants = {
            repo_name: "duckduckgo/ios"
          }
        when "macos"
          @constants = {
            repo_name: "duckduckgo/macos-browser"
          }
        end
      end

      def self.run(params)
        # Helper::GitHelper.setup_git_user
        params[:platform] ||= Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        setup_constants(params[:platform])

        options = params.values
        # options[:asana_user_id] = Helper::AsanaHelper.get_asana_user_id_for_github_handle(options[:github_handle])

        # release_branch_name, new_version = Helper::DdgAppleAutomationHelper.prepare_release_branch(
        #   params[:platform], params[:version], other_action
        # )
        # options[:version] = new_version
        # options[:release_branch_name] = release_branch_name

        # Helper::AsanaHelper.create_release_task(options[:platform], options[:version], options[:asana_user_id], options[:asana_access_token])

        update_asana_tasks_for_release(options)
      end

      def self.update_asana_tasks_for_release(params)
        # - name: Update Asana tasks for the release
        #   env:
        #     ASANA_ACCESS_TOKEN: ${{ secrets.ASANA_ACCESS_TOKEN }}
        #     GH_TOKEN: ${{ github.token }}
        #   run: |
        #     ./scripts/update_asana_for_release.sh \
        #       internal \
        #       ${{ steps.create_release_task.outputs.asana_task_id }} \
        #       ${{ vars.MACOS_APP_BOARD_VALIDATION_SECTION_ID }} \
        #       ${{ steps.create_release_task.outputs.marketing_version }}

        # # 1. Fetch task URLs from git commit messages
        # local last_release_tag
        # last_release_tag="$(gh api /repos/duckduckgo/macos-browser/releases/latest --jq .tag_name)"

        # local task_ids=()
        # while read -r line; do
        # 	local task_id
        # 	task_id="$(get_task_id "$line")"
        # 	if [[ -n "$task_id" ]]; then
        # 		task_ids+=("$task_id")
        # 	fi
        # done <<< "$(find_task_urls_in_git_log "$last_release_tag")"

        # # 2. Fetch current release notes from Asana release task.
        # local release_notes
        # release_notes="$(fetch_current_release_notes "${release_task_id}")"

        client = Octokit::Client.new(access_token: params[:github_token])
        latest_public_release = client.latest_release(@constants[:repo_name])
        UI.message("Latest public release: #{latest_public_release.tag_name}")

        task_ids = Helper::AsanaHelper.get_task_ids_from_git_log(latest_public_release.tag_name)

        task_ids.each { |task| UI.message("Task: #{task}") }

        release_notes = Helper::AsanaHelper.fetch_release_notes("1208377683776446", params[:asana_access_token])

        UI.message("Release notes: #{release_notes}")

        # # 3. Construct new release task description
        # local html_notes
        # html_notes="$(construct_release_task_description)"

        # # 4. Update release task description
        # update_task_description "$html_notes"

        # # 5. Move all tasks (including release task itself) to the validation section
        # task_ids+=("${release_task_id}")
        # move_tasks_to_section "$target_section_id" "${task_ids[@]}"

        # # 6. Get the existing Asana tag for the release, or create a new one.
        # local tag_id
        # tag_id=$(find_or_create_asana_release_tag "$marketing_version")

        # # 7. Tag all tasks with the release tag
        # tag_tasks "$tag_id" "${task_ids[@]}"
      end

      def self.description
        "Starts a new release"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "The newly created release task ID"
      end

      def self.details
        <<-DETAILS
        This action performs the following tasks:
        * creates a new release branch,
        * updates version and build number,
        * updates embedded files,
        * pushes the changes to the remote repository,
        * creates a new Asana release task based off the provided task template.
        DETAILS
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.asana_access_token,
          FastlaneCore::ConfigItem.github_token,
          FastlaneCore::ConfigItem.platform,
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Version number to force (calculated automatically if not provided)",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :release_task_template_id,
                                       description: "Release task template ID",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_handle,
                                       description: "Github user handle",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
