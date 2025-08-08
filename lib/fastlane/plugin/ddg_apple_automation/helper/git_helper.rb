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
        Actions.sh("echo \"git config --global user.name '#{name}'\"")
        Actions.sh("echo \"git config --global user.email '#{email}'\"")
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
        latest_tag = `git tag --sort=-v:refname | grep '+#{platform}' | head -n 1`.chomp
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

      def self.latest_release(repo_name, prerelease, platform, github_token)
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
            matches_prerelease = prerelease == release.prerelease
            matches_platform && matches_prerelease
          end

          return matching_release if matching_release
          break if releases.size < page_size

          current_page += 1
        end

        return nil
      end
    end
  end
end
