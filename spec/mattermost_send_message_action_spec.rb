describe Fastlane::Actions::MattermostSendMessageAction do
  describe "run" do
    let(:params) do
      {
        mattermost_webhook_url: "http://example.com/webhook",
        github_handle: "user",
        template_name: "test_template"
      }
    end

    let(:user_mapping) { { "user" => "@mattermost_user" } }
    let(:template_content) { { "text" => "Hello <%= name %>" } }
    let(:processed_template) { "Hello World" }

    before do
      allow(YAML).to receive(:load_file).with(anything).and_return(user_mapping)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:path_for_asset_file).and_return("mock_path")
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:process_erb_template).and_return(processed_template)
      allow(YAML).to receive(:safe_load).and_return("text" => processed_template)
      allow(HTTParty).to receive(:post).and_return(double(success?: true))

      allow(ENV).to receive(:[]).with("NAME").and_return("World")
    end

    it "sends a message to Mattermost with correct payload" do
      expected_payload = {
        "channel" => "@mattermost_user",
        "username" => "GitHub Actions",
        "text" => "Hello World",
        "icon_url" => "https://duckduckgo.com/assets/logo_header.v108.svg"
      }

      expect(HTTParty).to receive(:post).with(
        "http://example.com/webhook",
        hash_including(
          headers: { 'Content-Type' => 'application/json' },
          body: expected_payload.to_json
        )
      ).and_return(double(success?: true))

      Fastlane::Actions::MattermostSendMessageAction.run(params)
    end

    it "skips sending if Mattermost user handle is unknown" do
      allow(YAML).to receive(:load_file).and_return({})

      expect(HTTParty).not_to receive(:post)
      expect(FastlaneCore::UI).to receive(:message).with("Mattermost user handle not known for user, skipping sending message")

      Fastlane::Actions::MattermostSendMessageAction.run(params)
    end

    it "handles unsuccessful HTTP response" do
      allow(HTTParty).to receive(:post).and_return(double(success?: false, body: "Error message"))

      expect { Fastlane::Actions::MattermostSendMessageAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneError, "Failed to send message: Error message")
    end
  end

  describe "process_template" do
    it "processes ios-release-failed template" do
      expected = ":warning: **iOS release job failed** :thisisfine: | [:github: Workflow run summary](https://workflow.com)"

      expect(process_template("ios-release-failed", {
        "workflow_url" => "https://workflow.com"
      })).to eq(expected)
    end

    it "processes notarized-build-complete template" do
      expected = "Notarized macOS app `release` build is ready :goose_honk_tada: | [:github: Workflow run summary](https://workflow.com)"

      expect(process_template("notarized-build-complete", {
        "release_type" => "release",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected)
    end

    it "processes notarized-build-complete template with Asana task URL" do
      expected = "Notarized macOS app `release` build is ready :goose_honk_tada: | [:github: Workflow run summary](https://workflow.com) | [:asana: Asana Task](https://asana.com)"

      expect(process_template("notarized-build-complete", {
        "asana_task_url" => "https://asana.com",
        "release_type" => "release",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected)
    end

    it "processes notarized-build-failed template" do
      expected = ":rotating_light: Notarized macOS app `release` build failed | [:github: Workflow run summary](https://workflow.com)"

      expect(process_template("notarized-build-failed", {
        "release_type" => "release",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected)
    end

    it "processes notarized-build-failed template with Asana task URL" do
      expected = ":rotating_light: Notarized macOS app `release` build failed | [:github: Workflow run summary](https://workflow.com) | [:asana: Asana Task](https://asana.com)"

      expect(process_template("notarized-build-failed", {
        "asana_task_url" => "https://asana.com",
        "release_type" => "release",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected)
    end

    it "processes public-release-complete template" do
      expected = "macOS app has been successfully uploaded to testflight :goose_honk_tada: | [:github: Workflow run summary](https://workflow.com)"

      expect(process_template("public-release-complete", {
        "app_platform" => "macOS",
        "destination" => "testflight",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected)
    end

    it "processes public-release-failed template" do
      expected = ":rotating_light: macOS app testflight workflow failed | [:github: Workflow run summary](https://workflow.com)"

      expect(process_template("public-release-failed", {
        "destination" => "testflight",
        "workflow_url" => "https://workflow.com"
      })).to eq(expected)
    end

    it "processes variants-release-failed template" do
      expected = ":rotating_light: macOS app variants workflow failed | [:github: Workflow run summary](https://workflow.com)"

      expect(process_template("variants-release-failed", {
        "workflow_url" => "https://workflow.com"
      })).to eq(expected)
    end

    it "processes variants-release-published template" do
      expected = "macOS app variants have been published successfully :goose_honk_tada: | [:github: Workflow run summary](https://workflow.com)"

      expect(process_template("variants-release-published", {
        "workflow_url" => "https://workflow.com"
      })).to eq(expected)
    end

    def process_template(template_name, args)
      Fastlane::Actions::MattermostSendMessageAction.process_template(template_name, args)
    end
  end
end
