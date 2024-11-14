describe Fastlane::Actions::MattermostSendMessageAction do
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
