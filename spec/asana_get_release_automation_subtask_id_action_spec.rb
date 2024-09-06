describe Fastlane::Actions::AsanaGetReleaseAutomationSubtaskIdAction do
  describe "#run" do
    before do
      @asana_client_tasks = double
      asana_client = double("asana_client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:tasks).and_return(@asana_client_tasks)
      allow(@asana_client_tasks).to receive(:get_subtasks_for_task)
    end
    it "returns the 'Automation' subtask ID and sets GHA output when the subtask exists in the Asana task" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run)
      expect(@asana_client_tasks).to receive(:get_subtasks_for_task).and_return(
        [double(gid: "12345", name: "Automation", created_at: "2020-01-01T00:00:00.000Z")]
      )

      expect(test_action("https://app.asana.com/0/0/0")).to eq("12345")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_automation_task_id", "12345")
    end

    it "returns the oldest 'Automation' subtask when there are multiple subtasks with that name" do
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run)
      expect(@asana_client_tasks).to receive(:get_subtasks_for_task).and_return(
        [double(gid: "12345", name: "Automation", created_at: "2020-01-01T00:00:00.000Z"),
         double(gid: "431", name: "Automation", created_at: "2019-01-01T00:00:00.000Z"),
         double(gid: "12460", name: "Automation", created_at: "2020-01-05T00:00:00.000Z")]
      )

      expect(test_action("https://app.asana.com/0/0/0")).to eq("431")
    end

    it "returns nil when 'Automation' subtask does not exist in the Asana task" do
      allow(Fastlane::UI).to receive(:user_error!)
      expect(Fastlane::Actions::AsanaExtractTaskAssigneeAction).to receive(:run)
      expect(@asana_client_tasks).to receive(:get_subtasks_for_task).and_raise(StandardError, "API error")

      test_action("https://app.asana.com/0/0/0")
      expect(Fastlane::UI).to have_received(:user_error!).with("Failed to fetch 'Automation' subtasks for task 0: API error")
    end
  end

  def test_action(task_url)
    Fastlane::Actions::AsanaGetReleaseAutomationSubtaskIdAction.run(task_url: task_url)
  end
end
