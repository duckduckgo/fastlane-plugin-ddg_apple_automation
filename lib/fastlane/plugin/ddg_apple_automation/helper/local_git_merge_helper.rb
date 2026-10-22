require "base64"
require "open3"
require "tmpdir"

module Fastlane
  module Helper
    class LocalGitMergeHelper
      def self.merge(repo_name, source, base_branch, github_token)
        unless repo_name.match?(%r{\A[\w.-]+/[\w.-]+\z})
          raise "Invalid GitHub repository: #{repo_name}"
        end

        remote = "https://github.com/#{repo_name}.git"
        environment = git_environment(github_token)

        Dir.mktmpdir("release-merge-") do |directory|
          git(directory, environment, "init", "--quiet")
          git(directory, environment, "check-ref-format", "refs/heads/#{base_branch}")
          git(directory, environment, "check-ref-format", "refs/heads/#{source}")
          git(directory, environment, "fetch", "--no-tags", "--", remote, "refs/heads/#{base_branch}")
          git(directory, environment, "checkout", "--detach", "FETCH_HEAD")
          git(directory, environment, "fetch", "--no-tags", "--", remote, source)
          source_sha = git(directory, environment, "rev-parse", "FETCH_HEAD^{commit}").strip
          base_sha = git(directory, environment, "rev-parse", "HEAD").strip
          git(directory, environment, "merge", "--strategy=ort", "--no-ff", "--no-edit", source_sha)
          next if git(directory, environment, "rev-parse", "HEAD").strip == base_sha

          begin
            git(directory, environment, "push", remote, "HEAD:refs/heads/#{base_branch}")
          rescue StandardError => e
            raise "Could not publish merge to #{base_branch}. The remote base may have advanced or branch protections rejected the push. Fetch and rerun the release merge: #{e.message}"
          end
        end
      end

      def self.git_environment(github_token)
        authorization = Base64.strict_encode64("x-access-token:#{github_token}")
        {
          'GIT_TERMINAL_PROMPT' => '0',
          'GIT_AUTHOR_NAME' => 'Dax the Duck',
          'GIT_AUTHOR_EMAIL' => 'dax@duckduckgo.com',
          'GIT_COMMITTER_NAME' => 'Dax the Duck',
          'GIT_COMMITTER_EMAIL' => 'dax@duckduckgo.com',
          'GIT_CONFIG_COUNT' => '3',
          'GIT_CONFIG_KEY_0' => 'http.https://github.com/.extraheader',
          'GIT_CONFIG_VALUE_0' => '',
          'GIT_CONFIG_KEY_1' => 'http.https://github.com/.extraheader',
          'GIT_CONFIG_VALUE_1' => "AUTHORIZATION: basic #{authorization}",
          'GIT_CONFIG_KEY_2' => 'credential.helper',
          'GIT_CONFIG_VALUE_2' => ''
        }
      end

      def self.git(directory, environment, *arguments)
        stdout, stderr, status = Open3.capture3(environment, 'git', '-C', directory, *arguments)
        return stdout if status.success?

        # Git output can echo credentials.
        authorization = environment.fetch('GIT_CONFIG_VALUE_1').split.last
        token = Base64.strict_decode64(authorization).delete_prefix('x-access-token:')
        detail = "#{stdout}\n#{stderr}".gsub(authorization, '[REDACTED]')
        detail = detail.gsub(token, '[REDACTED]') unless token.empty?
        raise "git #{arguments.first} failed: #{detail.strip}"
      end

      private_class_method :git_environment, :git
    end
  end
end
