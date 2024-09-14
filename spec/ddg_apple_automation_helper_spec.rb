describe Fastlane::Helper::DdgAppleAutomationHelper do
  describe "#load_file" do
    it "shows error if provided file does not exist" do
      allow(Fastlane::UI).to receive(:user_error!)
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      load_file("file")
      expect(Fastlane::UI).to have_received(:user_error!).with("Error: The file 'file' does not exist.")
    end

    def load_file(file)
      Fastlane::Helper::DdgAppleAutomationHelper.load_file(file)
    end
  end
end
