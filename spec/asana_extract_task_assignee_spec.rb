describe Fastlane::Actions::AsanaExtractTaskAssigneeAction do
  describe "#run" do
    it "returns the assignee ID when Asana task is assigned" do
      expect(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          parsed_response: { 'data' => { 'assignee' => { 'gid' => '67890' } } }
        )
      )

      expect(test_action("12345")).to eq("67890")
    end

    it "returns nil when Asana task is not assigned" do
      expect(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          parsed_response: { 'data' => { 'assignee' => nil } }
        )
      )

      expect(test_action("12345")).to eq(nil)
    end

    it "shows error when failed to fetch task assignee" do
      expect(HTTParty).to receive(:get).and_return(
        double(
          success?: false,
          code: 401,
          message: "Unauthorized"
        )
      )

      expect(Fastlane::UI).to receive(:user_error!).with("Failed to fetch task assignee: (401 Unauthorized)")

      test_action("12345")
    end

    it "sets GHA output" do
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

      expect(HTTParty).to receive(:get).and_return(
        double(
          success?: true,
          parsed_response: { 'data' => { 'assignee' => { 'gid' => '67890' } } }
        )
      )

      expect(test_action("12345")).to eq("67890")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("asana_assignee_id", "67890")
    end
  end

  def test_action(task_id)
    Fastlane::Actions::AsanaExtractTaskAssigneeAction.run(task_id: task_id)
  end
end
