describe Fastlane::Actions::AsanaGetReleaseAutomationSubtaskIdAction do
  describe "#run" do
    it "returns the 'Automation' subtask ID when it exists in the Asana task" do
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run)
      expect(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          parsed_response: { 'data' => [
            { 'gid' => '12345', 'name' => 'Automation', 'created_at' => '2020-01-01T00:00:00.000Z' }
          ] }
        )
      )

      expect(test_action("https://app.asana.com/0/0/0")).to eq("12345")
    end

    it "returns the oldest 'Automation' subtask when there are multiple subtasks with that name" do
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run)
      expect(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          parsed_response: { 'data' => [
            { 'gid' => '12345', 'name' => 'Automation', 'created_at' => '2020-01-01T00:00:00.000Z' },
            { 'gid' => '431', 'name' => 'Automation', 'created_at' => '2019-01-01T00:00:00.000Z' },
            { 'gid' => '12460', 'name' => 'Automation', 'created_at' => '2020-01-05T00:00:00.000Z' }
          ] }
        )
      )

      expect(test_action("https://app.asana.com/0/0/0")).to eq("431")
    end

    it "returns nil when 'Automation' subtask does not exist in the Asana task" do
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run)
      expect(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          parsed_response: { 'data' => [] }
        )
      )

      expect(test_action("https://app.asana.com/0/0/0")).to eq(nil)
    end

    it "shows error when failed to fetch task subtasks" do
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run)
      expect(HTTParty).to receive(:get).and_return(
        double(
          success?: false,
          code: 401,
          message: "Unauthorized"
        )
      )

      expect(Fastlane::UI).to receive(:user_error!).with("Failed to fetch 'Automation' subtask: (401 Unauthorized)")

      test_action("https://app.asana.com/0/0/0")
    end

    it "sets GHA output" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run)
      expect(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          parsed_response: { 'data' => [
            { 'gid' => '12345', 'name' => 'Automation', 'created_at' => '2020-01-01T00:00:00.000Z' }
          ] }
        )
      )

      expect(test_action("https://app.asana.com/0/0/0")).to eq("12345")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_automation_task_id", "12345")
    end
  end

  def test_action(task_url)
    Fastlane::Actions::AsanaGetReleaseAutomationSubtaskIdAction.run(task_url: task_url)
  end
end
