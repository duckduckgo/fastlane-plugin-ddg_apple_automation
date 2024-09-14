describe Fastlane::Actions::AsanaUploadAction do
  describe "#run" do
    it "calls helper" do
      task_id = "12345"
      file_name = "file.txt"
      asana_access_token = "secret-token"
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:upload_file_to_asana_task)
        .with(task_id, file_name, asana_access_token)
      test_action(task_id, file_name, asana_access_token)
    end

    def test_action(task_id, file_name, asana_access_token)
      Fastlane::Actions::AsanaUploadAction.run(task_id: task_id, file_name: file_name, asana_access_token: asana_access_token)
    end
  end
end
