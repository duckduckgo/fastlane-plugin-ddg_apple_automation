describe Fastlane::Actions::AsanaGetUserIdForGithubHandleAction do
  describe "#run" do
    let(:yaml_content) do
      {
        "duck" => "123",
        "goose" => "456",
        "pigeon" => nil,
        "hawk" => ""
      }
    end

    before do
      allow(YAML).to receive(:load_file).and_return(yaml_content)
    end

    it "sets the user ID output and GHA output correctly" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

      expect(test_action("duck")).to eq("123")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_user_id", "123")
    end

    it "shows warning when handle does not exist" do
      expect(Fastlane::UI).to receive(:warning).with("Asana User ID not found for GitHub handle: chicken")
      test_action("chicken")
    end

    it "shows warning when handle is nil" do
      expect(Fastlane::UI).to receive(:warning).with("Asana User ID not found for GitHub handle: pigeon")
      test_action("pigeon")
    end

    it "shows warning when handle is empty" do
      expect(Fastlane::UI).to receive(:warning).with("Asana User ID not found for GitHub handle: hawk")
      test_action("hawk")
    end
  end

  def test_action(github_handle)
    Fastlane::Actions::AsanaGetUserIdForGithubHandleAction.run(github_handle: github_handle)
  end
end
