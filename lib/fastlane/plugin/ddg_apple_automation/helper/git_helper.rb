require "fastlane/action"
require "fastlane_core/ui/ui"
require "octokit"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class GitHelper
      def self.repo_name
        "duckduckgo/apple-browsers"
      end

      def self.setup_git_user(name: "Dax the Duck", email: "dax@duckduckgo.com")
        Actions.sh("git config --global user.name '#{name}'")
        Actions.sh("git config --global user.email '#{email}'")
      end

      def self.assert_main_branch(branch)
        unless self.assert_branch(branch, allowed_branches: ["main"])
          UI.user_error!("Main branch required, got '#{branch}'.")
        end
      end

      def self.assert_release_or_hotfix_branch(branch)
        unless self.assert_branch(branch, allowed_branches: [%r{release/*}, %r{hotfix/*}])
          UI.user_error!("Release or hotfix branch required, got '#{branch}'.")
        end
      end

      def self.assert_branch(branch, allowed_branches:)
        allowed_branches.any? { |allowed_branch| allowed_branch.match?(branch) }
      end

      def self.merge_branch(repo_name, branch, base_branch, github_token)
        client = Octokit::Client.new(access_token: github_token)
        begin
          client.merge(repo_name, base_branch, branch)
          UI.success("Merged #{branch} branch to #{base_branch}")
        rescue StandardError => e
          UI.important("Failed to merge #{branch} branch to #{base_branch}: #{e}")
          raise e
        end
      end

      def self.delete_branch(repo_name, branch, github_token)
        client = Octokit::Client.new(access_token: github_token)
        begin
          client.delete_branch(repo_name, branch)
          UI.success("Deleted #{branch}")
        rescue StandardError => e
          UI.important("Failed to delete #{branch} branch: #{e}")
          raise e
        end
      end

      def self.assert_branch_has_changes(release_branch, platform)
        state = release_branch_state(release_branch, platform)
        if state[:is_tagged]
          UI.important("Release branch's HEAD is already tagged. Skipping automatic release.")
          return false
        end

        changed_files = `git diff --name-only "#{state[:latest_tag]}".."origin/#{release_branch}"`
                        .split("\n")
                        .filter { |file| !file.match?(/^(:?\.github|scripts|fastlane)/) }

        changed_files.any?
      end

      def self.untagged_commit_sha(release_branch, platform)
        state = release_branch_state(release_branch, platform)
        state[:release_branch_sha] unless state[:is_tagged]
      end

      def self.release_branch_state(release_branch, platform)
        latest_tag = `git tag --sort=-creatordate | grep '+#{platform}' | head -n 1`.chomp
        latest_tag_sha = commit_sha_for_tag(latest_tag)
        release_branch_sha = `git rev-parse "origin/#{release_branch}"`.chomp

        {
          is_tagged: latest_tag_sha == release_branch_sha,
          latest_tag: latest_tag,
          latest_tag_sha: latest_tag_sha,
          release_branch_sha: release_branch_sha
        }
      end

      def self.commit_sha_for_tag(tag)
        `git rev-parse "#{tag}"^{}`.chomp
      end

      def self.find_latest_marketing_version(github_token, platform)
        latest_internal_release = Helper::GitHelper.latest_release(Helper::GitHelper.repo_name, true, platform, github_token)

        version = extract_version_from_tag_name(latest_internal_release&.tag_name)
        if version.to_s.empty?
          UI.user_error!("Failed to find latest marketing version")
          return
        end
        unless self.validate_semver(version)
          UI.user_error!("Invalid marketing version: #{version}, expected format: MAJOR.MINOR.PATCH")
          return
        end
        version
      end

      def self.extract_version_from_tag_name(tag_name)
        # Remove build number (if present) and platform suffix from the tag name
        tag_name&.split(/[-+]/)&.first
      end

      def self.extract_version_from_branch_name(branch_name)
        version = branch_name.split('/')&.last
        version if validate_semver(version)
      end

      def self.validate_semver(version)
        # we only need basic "x.y.z" validation here
        version.match?(/\A\d+\.\d+\.\d+\z/)
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def self.latest_release(repo_name, prerelease, platform, github_token, allow_drafts: false)
        client = Octokit::Client.new(access_token: github_token)

        current_page = 1
        page_size = 25

        loop do
          releases = client.releases(repo_name, per_page: page_size, page: current_page)
          break if releases.empty?

          # If `prerelease` is true, return the latest release that matches the platform and is not public.
          # If `prerelease` is false, then ensure that the release is public.
          matching_release = releases.find do |release|
            matches_platform = platform.nil? || release.tag_name.end_with?("+#{platform}")
            if allow_drafts
              matches_platform ||= release.name.end_with?("+#{platform}")
            end
            matches_prerelease = prerelease == release.prerelease
            matches_platform && matches_prerelease
          end

          return matching_release if matching_release
          break if releases.size < page_size

          current_page += 1
        end

        return nil
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.delete_release(release_url, github_token)
        client = Octokit::Client.new(access_token: github_token)
        client.delete_release(release_url)
      end

      def self.freeze_release_branch(platform, github_token, other_action)
        UI.message("Checking latest marketing version")
        latest_marketing_version = find_latest_marketing_version(github_token, platform)
        UI.success("Latest marketing version: #{latest_marketing_version}")

        draft_public_release_name = "#{latest_marketing_version}+#{platform}"

        UI.message("Will freeze release branch for #{latest_marketing_version} by creating a draft public release")
        UI.message("First we'll check if #{draft_public_release_name} release exists.")

        UI.message("Checking for draft public release #{draft_public_release_name}")
        latest_public_release = latest_release(Helper::GitHelper.repo_name, false, platform, github_token, allow_drafts: true)
        UI.success("Latest public release (including drafts): #{latest_public_release.name}")

        if latest_public_release.name == draft_public_release_name
          UI.success("Draft public release #{draft_public_release_name} already exists. Nothing to do as the branch is already frozen.")
          return
        end

        UI.message("Creating draft public release #{draft_public_release_name}")

        description = <<~DESCRIPTION
          This draft release is here to indicate that the release branch is frozen.
          New internal releases on `release/#{platform}/#{latest_marketing_version}` branch cannot be created.
          If you need to bump the internal release, please manually delete this draft release.
        DESCRIPTION

        other_action.set_github_release(
          repository_name: repo_name,
          api_bearer: github_token,
          description: description,
          name: draft_public_release_name,
          tag_name: "",
          is_draft: true,
          is_prerelease: false
        )
        UI.success("Draft public release #{draft_public_release_name} created")
      end

      def self.assert_release_branch_is_not_frozen(release_branch, platform, github_token)
        UI.message("Checking if release on #{release_branch} branch can be bumped.")

        marketing_version = extract_version_from_branch_name(release_branch)
        if marketing_version.to_s.empty?
          UI.user_error!("Unable to extract version from '#{release_branch}' branch name.")
          return
        end

        UI.message("Version extracted from '#{release_branch}' branch name: #{marketing_version}")

        draft_public_release_name = "#{marketing_version}+#{platform}"
        UI.message("Checking if draft public release #{draft_public_release_name} exists.")

        latest_public_release = latest_release(repo_name, false, platform, github_token, allow_drafts: true)
        UI.success("Latest public release (including drafts): #{latest_public_release.name}")

        if latest_public_release.name == draft_public_release_name && latest_public_release.draft
          UI.important("Draft public release #{draft_public_release_name} exists, which means the release branch is frozen.")
          UI.error("🚨 If you need to bump the release:")
          UI.error(" - Delete the draft public release to unfreeze the branch")
          UI.error("    - Release URL: ➡️ #{latest_public_release.html_url} ⬅️")
          UI.error(" - Restart the workflow")
          UI.user_error!("Release branch is frozen.")
          return
        end

        UI.success("No draft public release #{draft_public_release_name} found - the release isn't frozen.")
      end

      def self.unfreeze_release_branch(release_branch, platform, github_token)
        marketing_version = extract_version_from_branch_name(release_branch)
        if marketing_version.to_s.empty?
          UI.user_error!("Unable to extract version from '#{release_branch}' branch name.")
          return
        end

        UI.message("Unfreezing release branch #{release_branch} if needed")

        draft_public_release_name = "#{marketing_version}+#{platform}"
        UI.message("Checking if draft public release #{draft_public_release_name} exists.")

        latest_public_release = latest_release(repo_name, false, platform, github_token, allow_drafts: true)
        UI.success("Latest public release (including drafts): #{latest_public_release.name}")

        unless latest_public_release.name == draft_public_release_name && latest_public_release.draft
          UI.important("Latest public release is not a draft. No need to delete it.")
          return
        end

        UI.message("Release version matches and it's a draft release.")
        UI.important("Deleting draft public release #{draft_public_release_name}")
        delete_release(latest_public_release.url, github_token)
        UI.success("Draft public release #{draft_public_release_name} deleted")
      end

      def self.commit_author(repo_name, commit_sha, github_token)
        client = Octokit::Client.new(access_token: github_token)

        commit = client.commit(repo_name, commit_sha)
        commit.author&.login
      end
    end
  end
end
