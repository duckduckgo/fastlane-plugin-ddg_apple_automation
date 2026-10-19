describe Fastlane::Helper::EmbeddedFilesHelper do
  describe "#verify_file_updates_allowed" do
    subject { Fastlane::Helper::EmbeddedFilesHelper.verify_file_updates_allowed(platform, filenames, "Unexpected modified file") }

    context "on iOS" do
      let(:platform) { "ios" }

      context "with the embedded files update_embedded.sh writes" do
        let(:filenames) do
          [
            "Core/ContentBlocker/AppPrivacyConfigurationDataProvider.swift",
            "Core/ContentBlocker/AppTrackerDataSetProvider.swift",
            "Core/ContentBlocker/PrivacyConfiguration/ios-config.json",
            "Core/ContentBlocker/Domain/trackerData.json"
          ]
        end

        it "allows them" do
          expect { subject }.not_to raise_error
        end
      end

      context "with a file outside the embedded files" do
        let(:filenames) { ["Core/ContentBlocker/ContentBlockerRulesUserScript.swift"] }

        it "aborts" do
          expect { subject }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, "Unexpected modified file: Core/ContentBlocker/ContentBlockerRulesUserScript.swift.")
        end
      end
    end

    context "on macOS" do
      let(:platform) { "macos" }

      context "with the embedded files update_embedded.sh writes" do
        let(:filenames) do
          [
            "DuckDuckGo/ContentBlocker/AppPrivacyConfigurationDataProvider.swift",
            "DuckDuckGo/ContentBlocker/AppTrackerDataSetProvider.swift",
            "DuckDuckGo/ContentBlocker/Resources/trackerData.json",
            "DuckDuckGo/ContentBlocker/Resources/macos-config.json",
            "../SharedPackages/DataBrokerProtectionCore/Sources/DataBrokerProtectionCore/BundleResources/JSON/example.json"
          ]
        end

        it "allows them" do
          expect { subject }.not_to raise_error
        end
      end

      context "with a file outside the embedded files" do
        let(:filenames) { ["DuckDuckGo/ContentBlocker/ContentBlocking.swift"] }

        it "aborts" do
          expect { subject }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, "Unexpected modified file: DuckDuckGo/ContentBlocker/ContentBlocking.swift.")
        end
      end
    end
  end
end
