require "fastlane_core/configuration/config_item"
require "fastlane_core/ui/ui"
require "semantic"
require_relative "github_actions_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class DdgAppleAutomationHelper
      ASANA_APP_URL = "https://app.asana.com/0/0"
      ASANA_TASK_URL_REGEX = %r{https://app.asana.com/[0-9]/[0-9]+/([0-9]+)(:/f)?}

      DEFAULT_BRANCH = 'main'
      RELEASE_BRANCH = 'release'
      HOTFIX_BRANCH = 'hotfix'

      INFO_PLIST = 'DuckDuckGo/Info.plist'
      VERSION_CONFIG_PATH = 'Configuration/Version.xcconfig'
      BUILD_NUMBER_CONFIG_PATH = 'Configuration/BuildNumber.xcconfig'
      VERSION_CONFIG_DEFINITION = 'MARKETING_VERSION'
      BUILD_NUMBER_CONFIG_DEFINITION = 'CURRENT_PROJECT_VERSION'

      UPGRADABLE_EMBEDDED_FILES = {
        ios: Set.new([
                       'Core/AppPrivacyConfigurationDataProvider.swift',
                       'Core/AppTrackerDataSetProvider.swift',
                       'Core/ios-config.json',
                       'Core/trackerData.json'
                     ]),
        macos: Set.new([
                         'DuckDuckGo/ContentBlocker/AppPrivacyConfigurationDataProvider.swift',
                         'DuckDuckGo/ContentBlocker/AppTrackerDataSetProvider.swift',
                         'DuckDuckGo/ContentBlocker/trackerData.json',
                         'DuckDuckGo/ContentBlocker/macos-config.json'
                       ])
      }.freeze

      def self.code_freeze_prechecks(other_action)
        other_action.ensure_git_status_clean
        other_action.ensure_git_branch(branch: DEFAULT_BRANCH)
        other_action.git_pull

        other_action.git_submodule_update(recursive: true, init: true)
        other_action.ensure_git_status_clean
      end

      def self.validate_new_version(version)
        current_version = current_version()
        user_version = format_version(version)
        new_version = user_version.nil? ? bump_minor_version(current_version) : user_version

        UI.important("Current version in project settings is #{current_version}.")
        UI.important("New version is #{new_version}.")

        if UI.interactive? && !UI.confirm("Do you want to continue?")
          UI.abort_with_message!('Aborted by user.')
        end
        new_version
      end

      def self.format_version(version)
        user_version = nil

        unless version.nil?
          version_numbers = version.split('.')
          version_numbers[3] = 0
          version_numbers.map! { |element| element.nil? ? 0 : element }
          user_version = "#{version_numbers[0]}.#{version_numbers[1]}.#{version_numbers[2]}"
        end

        user_version
      end

      # Updates version in the config file by bumping the minor (second) number
      #
      # @param [String] current version
      # @return [String] updated version
      #
      def self.bump_minor_version(version)
        Semantic::Version.new(version).increment!(:minor).to_s
      end

      # Updates version in the config file by bumping the patch (third) number
      #
      # @param [String] current version
      # @return [String] updated version
      #
      def self.bump_patch_version(version)
        Semantic::Version.new(version).increment!(:patch).to_s
      end

      # Reads build number from the config file
      #
      # @return [String] build number read from the file, or nil in case of failure
      #
      def self.current_build_number
        current_build_number = 0

        file_data = File.read(BUILD_NUMBER_CONFIG_PATH).split("\n")
        file_data.each do |line|
          current_build_number = line.split('=')[1].strip.to_i if line.start_with?(BUILD_NUMBER_CONFIG_DEFINITION)
        end

        current_build_number
      end

      # Updates version in the config file
      #
      # @return [String] version read from the file, or nil in case of failure
      #
      def self.current_version
        current_version = nil

        file_data = File.read(VERSION_CONFIG_PATH).split("\n")
        file_data.each do |line|
          current_version = line.split('=')[1].strip if line.start_with?(VERSION_CONFIG_DEFINITION)
        end

        current_version
      end

      def self.create_release_branch(version)
        UI.message("Creating new release branch for #{version}")
        release_branch = "#{RELEASE_BRANCH}/#{version}"

        # Abort if the branch already exists
        UI.abort_with_message!("Branch #{release_branch} already exists in this repository. Aborting.") unless Actions.sh(
          'git', 'branch', '--list', release_branch
        ).empty?

        # Create the branch and push
        Actions.sh('git', 'checkout', '-b', release_branch)
        Actions.sh('git', 'push', '-u', 'origin', release_branch)
      end

      def self.update_embedded_files(params, other_action)
        Actions.sh("./scripts/update_embedded.sh")

        # Verify no unexpected files were modified
        git_status = Actions.sh('git', 'status')
        modified_files = git_status.split("\n").select { |line| line.include?('modified:') }
        modified_files = modified_files.map { |str| str.split(':')[1].strip.delete_prefix('../') }

        modified_files.each do |modified_file|
          UI.abort_with_message!("Unexpected change to #{modified_file}.") unless UPGRADABLE_EMBEDDED_FILES[params[:platform]].any? do |s|
            s.include?(modified_file)
          end
        end

        # Run tests (CI will run them separately)
        # run_tests(scheme: 'DuckDuckGo Privacy Browser') unless is_ci

        # Everything looks good: commit and push
        unless modified_files.empty?
          modified_files.each { |modified_file| sh('git', 'add', modified_file.to_s) }
          Actions.sh('git', 'commit', '-m', 'Update embedded files')
          other_action.ensure_git_status_clean
        end
      end

      def self.update_version_config(version)
        File.write(VERSION_CONFIG_PATH, "#{VERSION_CONFIG_DEFINITION} = #{version}\n")
        git_commit(
          path: VERSION_CONFIG_PATH,
          message: "Set marketing version to #{version}"
        )
      end

      def self.process_erb_template(erb_file_path, args)
        template_content = load_file(erb_file_path)
        unless template_content
          UI.user_error!("Template file not found: #{erb_file_path}")
          return
        end

        erb_template = ERB.new(template_content)
        erb_template.result_with_hash(args)
      end

      def self.compute_tag(is_prerelease)
        version = File.read("Configuration/Version.xcconfig").chomp.split(" = ").last
        build_number = File.read("Configuration/BuildNumber.xcconfig").chomp.split(" = ").last
        if is_prerelease
          tag = "#{version}-#{build_number}"
        else
          tag = version
          promoted_tag = "#{version}-#{build_number}"
        end

        return tag, promoted_tag
      end

      def self.path_for_asset_file(file)
        File.expand_path("../assets/#{file}", __dir__)
      end

      def self.load_file(file)
        File.read(file)
      rescue StandardError
        UI.user_error!("Error: The file '#{file}' does not exist.")
      end

      def self.sanitize_asana_html_notes(content)
        content.gsub(/\s+/, ' ')                           # replace multiple whitespaces with a single space
               .gsub(/>\s+</, '><')                        # remove spaces between HTML tags
               .strip                                      # remove leading and trailing whitespaces
               .gsub(%r{<br\s*/?>}, "\n")                  # replace <br> tags with newlines
      end
    end
  end
end

module FastlaneCore
  class ConfigItem
    def self.asana_access_token
      FastlaneCore::ConfigItem.new(key: :asana_access_token,
                                   env_name: "ASANA_ACCESS_TOKEN",
                                   description: "Asana access token",
                                   optional: false,
                                   sensitive: true,
                                   type: String,
                                   verify_block: proc do |value|
                                     UI.user_error!("ASANA_ACCESS_TOKEN is not set") if value.to_s.length == 0
                                   end)
    end

    def self.github_token
      FastlaneCore::ConfigItem.new(key: :github_token,
                                   env_name: "GITHUB_TOKEN",
                                   description: "GitHub token",
                                   optional: false,
                                   sensitive: true,
                                   type: String,
                                   verify_block: proc do |value|
                                     UI.user_error!("GITHUB_TOKEN is not set") if value.to_s.length == 0
                                   end)
    end

    def self.platform
      FastlaneCore::ConfigItem.new(key: :platform,
                                   description: "Platform (iOS or macOS) - optionally to override lane context value",
                                   optional: true,
                                   type: String,
                                   verify_block: proc do |value|
                                     UI.user_error!("platform must be equal to 'ios' or 'macos'") unless ['ios', 'macos'].include?(value.to_s)
                                   end)
    end
  end
end
