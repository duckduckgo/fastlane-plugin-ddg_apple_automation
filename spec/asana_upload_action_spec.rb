describe Fastlane::Actions::AsanaUploadAction do
  describe "#run" do
    before do
      @task = double("task")
      @asana_client_tasks = double("asana_client_tasks")
      asana_client = double("asana_client")
      allow(Asana::Client).to receive(:new).and_return(asana_client)
      allow(asana_client).to receive(:tasks).and_return(@asana_client_tasks)
    end
    it "uploads a file successfully" do
      allow(@asana_client_tasks).to receive(:find_by_id).with("123").and_return(@task)
      allow(@task).to receive(:attach).with(filename: "path/to/file.txt", mime: "application/octet-stream")

      expect { test_action("123", "path/to/file.txt") }.not_to raise_error
    end

    it "shows error if failure" do
      allow(@asana_client_tasks).to receive(:find_by_id).with("123").and_return(@task)
      allow(@task).to receive(:attach).and_raise(StandardError.new("API Error"))

      expect(Fastlane::UI).to receive(:user_error!).with("Failed to upload file to Asana task: API Error")
      test_action("123", "path/to/file.txt")
    end
  end

  def test_action(task_id, file_name)
    Fastlane::Actions::AsanaUploadAction.run(task_id: task_id,
                                             file_name: file_name)
  end
end
