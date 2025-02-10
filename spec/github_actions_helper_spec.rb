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

  describe ".assert_branch_has_changes" do
    let(:platform) { "ios" }
    let(:version) { "1.0.0+#{platform}" }

    before do
      allow(Fastlane::UI).to receive(:important)
    end

    context "when the release branch has no changes since the latest tag" do
      it "returns false and shows a message" do
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git tag --sort=-v:refname | grep '+#{platform}' | head -n 1").and_return("#{version}\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git rev-parse \"#{version}\"^{}").and_return("abc123\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with('git rev-parse "origin/release_branch"').and_return("abc123\n")

        expect(Fastlane::Helper::GitHelper.assert_branch_has_changes("release_branch", platform)).to eq(false)
        expect(Fastlane::UI).to have_received(:important).with("Release branch's HEAD is already tagged. Skipping automatic release.")
      end
    end

    context "when the release branch has changes since the latest tag" do
      it "returns true" do
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git tag --sort=-v:refname | grep '+#{platform}' | head -n 1").and_return("#{version}\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git rev-parse \"#{version}\"^{}").and_return("abc123\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with('git rev-parse "origin/release_branch"').and_return("def456\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git diff --name-only \"#{version}\"..\"origin/release_branch\"").and_return("app/file1.rb\napp/file2.rb\n")

        expect(Fastlane::Helper::GitHelper.assert_branch_has_changes("release_branch", platform)).to eq(true)
      end
    end

    context "when changes are only in scripts or workflows" do
      it "returns false" do
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git tag --sort=-v:refname | grep '+#{platform}' | head -n 1").and_return("#{version}\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git rev-parse \"#{version}\"^{}").and_return("abc123\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with('git rev-parse "origin/release_branch"').and_return("def456\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git diff --name-only \"#{version}\"..\"origin/release_branch\"").and_return(".github/workflows/workflow.yml\nscripts/deploy.sh\nfastlane/Fastfile\n")

        expect(Fastlane::Helper::GitHelper.assert_branch_has_changes("release_branch", platform)).to eq(false)
      end
    end
  end

  def set_output(key, value)
    Fastlane::Helper::GitHubActionsHelper.set_output(key, value)
  end
end
