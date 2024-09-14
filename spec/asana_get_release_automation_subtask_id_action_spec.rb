describe Fastlane::Actions::AsanaGetReleaseAutomationSubtaskIdAction do
  describe "#run" do
    it "calls helper" do
      task_url = "https://app.asana.com/0/0/12345/f"
      asana_access_token = "secret-token"
      automation_subtask_id = "67890"
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:get_release_automation_subtask_id)
        .with(task_url, asana_access_token).and_return(automation_subtask_id)
      expect(test_action(task_url, asana_access_token)).to eq(automation_subtask_id)
    end

    def test_action(task_url, asana_access_token)
      Fastlane::Actions::AsanaGetReleaseAutomationSubtaskIdAction.run(task_url: task_url, asana_access_token: asana_access_token)
    end
  end
end
