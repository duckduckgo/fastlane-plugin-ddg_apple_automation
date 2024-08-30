describe Fastlane::Actions::AsanaUploadAction do
  describe "#run" do
    it "uploads a file successfully" do
      allow(HTTParty).to receive(:post).and_return(double(success?: true))
      allow(File).to receive(:open).with("path/to/file.txt").and_return(double)

      expect { test_action("12345", "path/to/file.txt") }.not_to raise_error
    end

    it "shows error if HTTP failure" do
      allow(HTTParty).to receive(:post).and_return(
        double(
          success?: false,
          code: 500,
          message: "Internal Server Error"
        )
      )
      allow(File).to receive(:open).with("path/to/file.txt").and_return(double)

      expect(Fastlane::UI).to receive(:user_error!).with("Failed to upload file to Asana task: (500 Internal Server Error)")
      test_action("12345", "path/to/file.txt")
    end

    it "shows error if file does not exist" do
      allow(HTTParty).to receive(:post).and_return(double(success?: true))
      expect(Fastlane::UI).to receive(:user_error!).with("Failed to open file: path/to/file.txt")
      test_action("12345", "path/to/file.txt")
    end
  end

  def test_action(task_id, file_name)
    Fastlane::Actions::AsanaUploadAction.run(task_id: task_id,
                                             file_name: file_name)
  end
end
