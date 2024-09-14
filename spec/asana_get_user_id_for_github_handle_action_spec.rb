describe Fastlane::Actions::AsanaGetUserIdForGithubHandleAction do
  describe "#run" do
    it "calls helper" do
      github_handle = "user"
      asana_user_id = "12345"
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:get_asana_user_id_for_github_handle)
        .with(github_handle).and_return(asana_user_id)
      expect(test_action(github_handle)).to eq(asana_user_id)
    end

    def test_action(github_handle)
      Fastlane::Actions::AsanaGetUserIdForGithubHandleAction.run(github_handle: github_handle)
    end
  end
end
