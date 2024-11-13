describe Fastlane::Helper::DdgAppleAutomationHelper do
  describe "#process_erb_template" do
    it "processes ERB template" do
      template = "<h1>Hello, <%= x %>!</h1>"
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:load_file).and_return(template)
      expect(process_erb_template("template.erb", { 'x' => "World" })).to eq("<h1>Hello, World!</h1>")
    end

    it "shows error if provided template file does not exist" do
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:load_file).and_return(nil)
      allow(Fastlane::UI).to receive(:user_error!)
      expect(ERB).not_to receive(:new)
      process_erb_template("file.erb", {})
      expect(Fastlane::UI).to have_received(:user_error!).with("Template file not found: file.erb")
    end

    def process_erb_template(erb_file_path, args)
      Fastlane::Helper::DdgAppleAutomationHelper.process_erb_template(erb_file_path, args)
    end
  end

  describe "#compute_tag" do
    describe "when is prerelease" do
      let(:is_prerelease) { true }

      it "computes tag and returns nil promoted tag" do
        allow(File).to receive(:read).with("Configuration/Version.xcconfig").and_return("MARKETING_VERSION = 1.0.0")
        allow(File).to receive(:read).with("Configuration/BuildNumber.xcconfig").and_return("CURRENT_PROJECT_VERSION = 123")
        expect(compute_tag(is_prerelease)).to eq(["1.0.0-123", nil])
      end
    end

    describe "when is public release" do
      let(:is_prerelease) { false }

      it "computes tag and promoted tag" do
        allow(File).to receive(:read).with("Configuration/Version.xcconfig").and_return("MARKETING_VERSION = 1.0.0")
        allow(File).to receive(:read).with("Configuration/BuildNumber.xcconfig").and_return("CURRENT_PROJECT_VERSION = 123")
        expect(compute_tag(is_prerelease)).to eq(["1.0.0", "1.0.0-123"])
      end
    end

    def compute_tag(is_prerelease)
      Fastlane::Helper::DdgAppleAutomationHelper.compute_tag(is_prerelease)
    end
  end

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
