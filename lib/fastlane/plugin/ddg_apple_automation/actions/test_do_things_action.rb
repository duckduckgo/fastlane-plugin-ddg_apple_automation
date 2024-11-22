require "fastlane/action"
require "fastlane_core/configuration/config_item"

module Fastlane
  module Actions
    class TestDoThingsAction < Action
      def self.run(params)
        puts("oh yeah!") unless params[:is_hotfix]
      end

      def self.description
        "Uploads a file to an Asana task"
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
          FastlaneCore::ConfigItem.new(key: :is_hotfix,
                                       description: "Asana task ID",
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
