describe Fastlane::Actions::AsanaExtractTaskAssigneeAction do
  describe "#run" do
    it "calls helper" do
      task_id = "12345"
      assignee_id = "67890"
      asana_access_token = "secret-token"
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:extract_asana_task_assignee)
        .with(task_id, asana_access_token).and_return(assignee_id)
      expect(test_action(task_id, asana_access_token)).to eq(assignee_id)
    end
  end

  def test_action(task_id, asana_access_token)
    Fastlane::Actions::AsanaExtractTaskAssigneeAction.run(task_id: task_id, asana_access_token: asana_access_token)
  end
end
