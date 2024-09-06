describe Fastlane::Actions::AsanaExtractTaskAssigneeAction do
  describe "#run" do
    before do
      @asana_client_tasks = double
      asana_client = double("asana_client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:tasks).and_return(@asana_client_tasks)
      allow(@asana_client_tasks).to receive(:get_task)
    end

    it "returns the assignee ID and sets GHA output when Asana task is assigned" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
      expect(@asana_client_tasks).to receive(:get_task).and_return(
        double(assignee: double(gid: "67890"))
      )

      expect(test_action("12345")).to eq("67890")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_assignee_id", "67890")
    end

    it "returns nil when Asana task is not assigned" do
      expect(@asana_client_tasks).to receive(:get_task).and_return(
        double(assignee: double(gid: nil))
      )

      expect(test_action("12345")).to eq(nil)
    end

    it "shows error when failed to fetch task assignee" do
      expect(@asana_client_tasks).to receive(:get_task).and_raise(StandardError, "API error")
      expect(Fastlane::UI).to receive(:user_error!).with("Failed to fetch task assignee: API error")

      test_action("12345")
    end
  end

  def test_action(task_id)
    Fastlane::Actions::AsanaExtractTaskAssigneeAction.run(task_id: task_id)
  end
end
