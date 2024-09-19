require "fastlane/action"
require "fastlane_core/ui/ui"
require "octokit"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class GitHelper
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
    end
  end
end
