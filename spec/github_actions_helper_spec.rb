describe Fastlane::Helper::GitHubActionsHelper do
  describe "#set_output" do
    it "sets output when in CI and value is not empty" do
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(true)
      allow(Fastlane::Action).to receive(:sh)
      allow(ENV).to receive(:fetch).with("GITHUB_OUTPUT", "/dev/null").and_return("/dev/null")

      set_output("foo", "bar")
      expect(Fastlane::Action).to have_received(:sh).with("echo 'foo=bar' >> /dev/null")
    end

    it "honors GITHUB_OUTPUT environment variable when in CI" do
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(true)
      allow(Fastlane::Action).to receive(:sh)
      allow(ENV).to receive(:fetch).with("GITHUB_OUTPUT", "/dev/null").and_return("/tmp/github_output")

      set_output("foo", "bar")
      expect(Fastlane::Action).to have_received(:sh).with("echo 'foo=bar' >> /tmp/github_output")
    end

    it "does not set output when in CI and value is empty" do
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(true)
      allow(Fastlane::Action).to receive(:sh)

      set_output("foo", "")
      expect(Fastlane::Action).not_to have_received(:sh)
    end

    it "does not set output when in CI and value is nil" do
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(true)
      allow(Fastlane::Action).to receive(:sh)

      set_output("foo", nil)
      expect(Fastlane::Action).not_to have_received(:sh)
    end

    it "does not set output when not in CI" do
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(false)
      allow(Fastlane::Action).to receive(:sh)

      set_output("foo", "bar")
      expect(Fastlane::Action).not_to have_received(:sh)
    end

    it "fails when key is empty" do
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(true)
      allow(Fastlane::Action).to receive(:sh)
      expect(Fastlane::UI).to receive(:user_error!).with("Key cannot be empty")

      set_output("", "bar")
      expect(Fastlane::Action).not_to have_received(:sh)
    end
  end

  def set_output(key, value)
    Fastlane::Helper::GitHubActionsHelper.set_output(key, value)
  end
end
