require "fastlane/action"
require "fastlane_core/ui/ui"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class SentryHelper
      COMMON_APP_MODULES = [
        'GRDB'
      ].freeze

      APP_MODULES = {
        "ios" => [
          'Core'
        ],
        "macos" => []
      }.freeze

      def self.generate_grouping_rules(platform, output_file)
        UI.message("Starting Sentry Grouping Rules Generation...")

        app_modules = COMMON_APP_MODULES + APP_MODULES[platform]
        app_modules += find_modules_in_package_files
        app_modules = format_sentry_grouping_rules(app_modules)

        formatted_app_modules = app_modules.join("\n")

        File.write(output_file, formatted_app_modules)
        formatted_app_modules
      end

      def self.find_modules_in_package_files
        modules = []
        package_files = Actions.sh("git ls-files **/Package.swift ../SharedPackages/**/Package.swift").chomp.split("\n")
        package_files.each do |package_file|
          next unless File.exist?(package_file)

          content = File.read(package_file)
          content.scan(/\.library\s*\(\s*name:\s*"([^"]+)"/) do |match|
            modules << match[0]
          end
        end
        modules
      end

      def self.format_sentry_grouping_rules(modules)
        modules.map { |module_name| "stack.package:#{module_name} +app" }.sort!.uniq
      end
    end
  end
end
