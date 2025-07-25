require "fastlane_core/configuration/config_item"
require "fastlane_core/ui/ui"
require "httparty"
require "rexml/document"
require "semantic"
require_relative "github_actions_helper"
require_relative "git_helper"
require_relative "embedded_files_helper"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class DdgAppleAutomationHelper
      DEFAULT_BRANCH = 'main'
      RELEASE_BRANCH = 'release'
      HOTFIX_BRANCH = 'hotfix'

      INFO_PLIST = 'DuckDuckGo/Info.plist'
      ROOT_PLIST = 'DuckDuckGo/Settings.bundle/Root.plist'
      VERSION_CONFIG_PATH = 'Configuration/Version.xcconfig'
      BUILD_NUMBER_CONFIG_PATH = 'Configuration/BuildNumber.xcconfig'
      SPARKLE_CONFIG_PATH = 'Configuration/App/Sparkle.xcconfig'
      VERSION_CONFIG_DEFINITION = 'MARKETING_VERSION'
      BUILD_NUMBER_CONFIG_DEFINITION = 'CURRENT_PROJECT_VERSION'

      def self.release_branch_name(platform, version)
        "#{RELEASE_BRANCH}/#{platform}/#{version}"
      end

      def self.hotfix_branch_name(platform, version)
        "#{HOTFIX_BRANCH}/#{platform}/#{version}"
      end

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

        unless version.to_s.empty?
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

      def self.extract_version_from_tag(tag)
        if tag && !tag.empty?
          tag.split('-').first
        else
          Helper::DdgAppleAutomationHelper.current_version
        end
      end

      def self.prepare_release_branch(platform, version, other_action)
        code_freeze_prechecks(other_action) unless Helper.is_ci?
        new_version = validate_new_version(version)
        create_release_branch(platform, new_version)
        update_embedded_result = update_embedded_files(platform, other_action)
        if platform == "ios"
          # Any time we prepare a release branch for iOS the the build number should be reset to 0
          update_version_and_build_number_config(new_version, 0, other_action)
          update_root_plist_version(new_version, other_action)
        else
          update_version_config(new_version, other_action)
        end
        other_action.push_to_git_remote
        release_branch_name = release_branch_name(platform, new_version)
        Helper::GitHubActionsHelper.set_output("release_branch_name", release_branch_name)

        return release_branch_name, new_version, update_embedded_result
      end

      def self.prepare_hotfix_branch(github_token, platform, other_action, options)
        latest_public_release = Helper::GitHelper.latest_release(Helper::GitHelper.repo_name, false, platform, github_token)
        version = latest_public_release.tag_name
        Helper::GitHubActionsHelper.set_output("last_release", version)
        UI.user_error!("Unable to find latest release to hotfix") unless version
        source_version = validate_version_exists(version)
        new_version = validate_hotfix_version(source_version)
        release_branch_name = create_hotfix_branch(platform, source_version, new_version)
        if platform == "ios"
          update_version_and_build_number_config(new_version, 0, other_action)
          update_root_plist_version(new_version, other_action)
        else
          update_version_config(new_version, other_action)
        end
        other_action.push_to_git_remote
        increment_build_number(platform, options, other_action) if platform == "macos"
        Helper::GitHubActionsHelper.set_output("release_branch_name", release_branch_name)

        return release_branch_name, new_version
      end

      def self.create_hotfix_branch(platform, source_version, new_version)
        branch_name = hotfix_branch_name(platform, new_version)
        UI.message("Creating new hotfix release branch for #{new_version}")

        existing_branch = Actions.sh("git", "branch", "--list", branch_name).strip
        UI.abort_with_message!("Branch #{branch_name} already exists in this repository. Aborting.") unless existing_branch.empty?
        Actions.sh("git", "fetch", "--tags")
        Actions.sh("git", "checkout", "-b", branch_name, source_version)
        Actions.sh("git", "push", "-u", "origin", branch_name)
        branch_name
      end

      def self.validate_hotfix_version(source_version)
        new_version = bump_patch_version(source_version)
        UI.important("Release #{source_version} will be hotfixed as #{new_version}.")

        if UI.interactive? && !UI.confirm("Do you want to continue?")
          UI.abort_with_message!('Aborted by user.')
        end

        new_version
      end

      def self.validate_version_exists(version)
        user_version = format_version(version)
        UI.user_error!("Incorrect version provided: #{version}. Expected x.y.z+platform format.") unless user_version

        Actions.sh('git', 'fetch', '--tags')
        existing_tag = Actions.sh('git', 'tag', '--list', user_version).chomp
        existing_tag = nil if existing_tag.empty?

        UI.user_error!("Release #{user_version} not found. Make sure you've passed the version you want to make hotfix for, not the upcoming hotfix version.") unless existing_tag
        existing_tag
      end

      def self.create_release_branch(platform, version)
        UI.message("Creating new release branch for #{version}")
        release_branch = release_branch_name(platform, version)

        # Abort if the branch already exists
        UI.abort_with_message!("Branch #{release_branch} already exists in this repository. Aborting.") unless Actions.sh(
          'git', 'branch', '--list', release_branch
        ).empty?

        # Create the branch and push
        Actions.sh('git', 'checkout', '-b', release_branch)
        Actions.sh('git', 'push', '-u', 'origin', release_branch)
      end

      def self.update_embedded_files(platform, other_action)
        Helper::EmbeddedFilesHelper.update_embedded_files(platform, other_action)
      end

      def self.increment_build_number(platform, options, other_action)
        current_version = Helper::DdgAppleAutomationHelper.current_version
        current_build_number = Helper::DdgAppleAutomationHelper.current_build_number
        build_number = Helper::DdgAppleAutomationHelper.calculate_next_build_number(platform, options, other_action)

        UI.important("Current version in project settings is #{current_version} (#{current_build_number}).")
        UI.important("Will be updated to #{current_version} (#{build_number}).")

        if UI.interactive? && !UI.confirm("Do you want to continue?")
          UI.abort_with_message!('Aborted by user.')
        end

        update_version_and_build_number_config(current_version, build_number, other_action)
        other_action.push_to_git_remote
      end

      def self.calculate_next_build_number(platform, options, config = "release", bundle_id = nil, other_action)
        testflight_build_number = fetch_testflight_build_number(platform, options, bundle_id, other_action)
        xcodeproj_build_number = current_build_number
        if platform == "macos"
          appcast_build_number = fetch_appcast_build_number(config)
          current_release_build_number = [testflight_build_number, appcast_build_number].max
        else
          current_release_build_number = testflight_build_number
        end

        UI.message("TestFlight build number: #{testflight_build_number}")
        if platform == "macos"
          UI.message("Appcast.xml build number: #{appcast_build_number}")
          UI.message("Latest release build number (max of TestFlight and appcast): #{current_release_build_number}")
        end
        UI.message("Xcode project settings build number: #{xcodeproj_build_number}")

        if xcodeproj_build_number <= current_release_build_number
          next_build_number = current_release_build_number
        else
          UI.important("Warning: Build number from Xcode project (#{xcodeproj_build_number}) is higher than the current release (#{current_release_build_number}).")
          UI.message(%{This may be an error in the Xcode project settings, or it may mean that there is a hotfix
    release in progress and you're making a follow-up internal release that includes the hotfix.})
          if UI.interactive?
            build_numbers = {
              "Current release (#{current_release_build_number})" => current_release_build_number,
              "Xcode project (#{xcodeproj_build_number})" => xcodeproj_build_number
            }
            choice = UI.select("Please choose which build number to bump:", build_numbers.keys)
            next_build_number = build_numbers[choice]
          else
            UI.important("Shell is non-interactive, so we'll bump the Xcode project build number.")
            next_build_number = xcodeproj_build_number
          end
        end

        Helper::GitHubActionsHelper.set_output("next_build_number", next_build_number + 1)
        next_build_number + 1
      end

      def self.fetch_appcast_build_number(config)
        # This logic depends on the Sparkle.xcconfig file to contain the keys in the following format:
        # SPARKLE_URL_<CONFIG> for appcast URL for a given config
        # (e.g. SPARKLE_URL_ALPHA for Alpha or SPARKLE_URL_RELEASE for Release)
        url = File.readlines(SPARKLE_CONFIG_PATH)
                  .find { |l| l.downcase.start_with?("sparkle_url_#{config.downcase} = ") }
                  .chomp
                  .split(' = ')
                  .last
                  .tr('"', '')
                  .sub('$()', '')

        request = HTTParty.get(url)
        unless request.success?
          UI.important("Failed to fetch appcast for '#{config}' configuration from #{url}: #{request.response.code} #{request.response.message}")
          return 0
        end

        xml = request.body
        xml_data = REXML::Document.new(xml)
        versions = xml_data.get_elements('//rss/channel/item/sparkle:version').map { |e| e.text.split('.')[0].to_i }
        versions.max
      end

      def self.fetch_testflight_build_number(platform, options, bundle_id, other_action)
        args = {
          api_key: get_api_key(other_action),
          username: get_username(options),
          platform: platform == "macos" ? "osx" : "ios"
        }
        args[:app_identifier] = bundle_id if bundle_id
        other_action.latest_testflight_build_number(args)
      end

      def self.get_api_key(other_action)
        has_api_key = [
          "APPLE_API_KEY_ID",
          "APPLE_API_KEY_ISSUER",
          "APPLE_API_KEY_BASE64"
        ].map { |x| ENV.key?(x) }.reduce(&:&)

        if has_api_key
          other_action.app_store_connect_api_key(
            key_id: ENV.fetch("APPLE_API_KEY_ID", nil),
            issuer_id: ENV.fetch("APPLE_API_KEY_ISSUER", nil),
            key_content: ENV.fetch("APPLE_API_KEY_BASE64", nil),
            is_key_content_base64: true
          )
        end
      end

      def self.get_username(options)
        if Helper.is_ci?
          nil # not supported in CI
        elsif options[:username]
          options[:username]
        else
          git_user_email = `git config user.email`.chomp
          if git_user_email.end_with?("@duckduckgo.com")
            git_user_email
          end
        end
      end

      def self.update_version_config(version, other_action)
        File.write(VERSION_CONFIG_PATH, "#{VERSION_CONFIG_DEFINITION} = #{version}\n")
        other_action.git_commit(
          path: VERSION_CONFIG_PATH,
          message: "Set marketing version to #{version}"
        )
      end

      def self.update_version_and_build_number_config(version, build_number, other_action)
        File.write(VERSION_CONFIG_PATH, "#{VERSION_CONFIG_DEFINITION} = #{version}\n")
        File.write(BUILD_NUMBER_CONFIG_PATH, "#{BUILD_NUMBER_CONFIG_DEFINITION} = #{build_number}\n")
        other_action.git_commit(
          path: [
            VERSION_CONFIG_PATH,
            BUILD_NUMBER_CONFIG_PATH
          ],
          message: "Bump version to #{version} (#{build_number})"
        )
      end

      def self.update_root_plist_version(version, other_action)
        Actions.sh("/usr/libexec/PlistBuddy -c \"Set :PreferenceSpecifiers:0:DefaultValue #{version}\" #{ROOT_PLIST}")
        other_action.git_commit(
          path: ROOT_PLIST,
          message: "Update Root.plist version to #{version}"
        )
        UI.message("Updated Root.plist version to #{version}")
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

      def self.compute_tag(is_prerelease, platform)
        version = File.read(VERSION_CONFIG_PATH).chomp.split(" = ").last
        build_number = File.read(BUILD_NUMBER_CONFIG_PATH).chomp.split(" = ").last
        if is_prerelease
          tag = "#{version}-#{build_number}"
        else
          tag = version
          promoted_tag = "#{version}-#{build_number}"
        end

        if platform && !platform.empty?
          tag = "#{tag}+#{platform}"
          promoted_tag = "#{promoted_tag}+#{platform}" unless is_prerelease
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

    def self.is_scheduled_release
      FastlaneCore::ConfigItem.new(key: :is_scheduled_release,
                                   description: "Indicates whether the release was scheduled or started manually",
                                   optional: true,
                                   type: Boolean,
                                   default_value: false)
    end
  end
end
