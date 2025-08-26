describe Fastlane::Helper::GitHelper do
  let(:repo_name) { "repo_name" }
  let(:branch) { "branch" }
  let(:base_branch) { "base_branch" }
  let(:github_token) { "github_token" }
  let(:client) { double("client") }

  shared_context "common setup" do
    before do
      allow(Octokit::Client).to receive(:new).and_return(client)
      allow(Fastlane::UI).to receive(:success)
      allow(Fastlane::UI).to receive(:important)
    end
  end

  describe "#merge_branch" do
    subject { Fastlane::Helper::GitHelper.merge_branch(repo_name, branch, base_branch, github_token) }

    include_context "common setup"

    context "when merge is successful" do
      before do
        allow(client).to receive(:merge)
      end

      it "reports success" do
        expect { subject }.not_to raise_error

        expect(client).to have_received(:merge).with(repo_name, base_branch, branch)
        expect(Fastlane::UI).to have_received(:success).with("Merged #{branch} branch to #{base_branch}")
      end
    end

    context "when merge fails" do
      before do
        allow(client).to receive(:merge).and_raise(StandardError)
      end

      it "shows error" do
        expect { subject }.to raise_error(StandardError)

        expect(client).to have_received(:merge).with(repo_name, base_branch, branch)
        expect(Fastlane::UI).to have_received(:important).with("Failed to merge #{branch} branch to #{base_branch}: StandardError")
      end
    end
  end

  describe "#delete_branch" do
    subject { Fastlane::Helper::GitHelper.delete_branch(repo_name, branch, github_token) }

    include_context "common setup"

    context "when delete is successful" do
      before do
        allow(client).to receive(:delete_branch)
      end

      it "reports success" do
        expect { subject }.not_to raise_error

        expect(client).to have_received(:delete_branch).with(repo_name, branch)
        expect(Fastlane::UI).to have_received(:success).with("Deleted #{branch}")
      end
    end

    context "when delete fails" do
      before do
        allow(client).to receive(:delete_branch).and_raise(StandardError)
      end

      it "shows error" do
        expect { subject }.to raise_error(StandardError)

        expect(client).to have_received(:delete_branch).with(repo_name, branch)
        expect(Fastlane::UI).to have_received(:important).with("Failed to delete #{branch} branch: StandardError")
      end
    end
  end

  describe "#find_latest_marketing_version" do
    subject { Fastlane::Helper::GitHelper.find_latest_marketing_version("token", "ios") }

    before do
      @client = double
      allow(Octokit::Client).to receive(:new).and_return(@client)
    end

    it "returns the latest marketing version" do
      allow(@client).to receive(:releases).and_return(
        [
          double(tag_name: '2.0.0-1', prerelease: true),
          double(tag_name: '2.0.0-0+ios', prerelease: true),
          double(tag_name: '1.0.0', prerelease: false),
          double(tag_name: '1.0.0-1', prerelease: true),
          double(tag_name: '1.0.0-0', prerelease: true)
        ]
      )

      expect(subject).to eq("2.0.0")
    end

    it "strips build number and platform suffix from the latest marketing version" do
      allow(@client).to receive(:releases).and_return(
        [
          double(tag_name: '2.0.0-1+ios', prerelease: true)
        ]
      )

      expect(subject).to eq("2.0.0")
    end

    it "strips platform suffix from the latest marketing version when it's a public release" do
      allow(@client).to receive(:releases).and_return(
        [
          double(tag_name: '2.0.0+ios', prerelease: true)
        ]
      )

      expect(subject).to eq("2.0.0")
    end

    describe "when there is no latest release" do
      it "shows error" do
        allow(@client).to receive(:releases).and_return([])
        allow(Fastlane::UI).to receive(:user_error!)

        subject

        expect(Fastlane::UI).to have_received(:user_error!).with("Failed to find latest marketing version")
      end
    end

    describe "when latest release is not a valid semver" do
      it "shows error" do
        allow(@client).to receive(:releases).and_return([double(tag_name: '1.0+ios', prerelease: true)])
        allow(Fastlane::UI).to receive(:user_error!)

        subject

        expect(Fastlane::UI).to have_received(:user_error!).with("Invalid marketing version: 1.0, expected format: MAJOR.MINOR.PATCH")
      end
    end
  end

  describe "#extract_version_from_tag_name" do
    it "returns the version" do
      expect(extract_version_from_tag_name("1.0.0")).to eq("1.0.0")
      expect(extract_version_from_tag_name("v1.0.0")).to eq("v1.0.0")
      expect(extract_version_from_tag_name("1.105.0-251")).to eq("1.105.0")
    end

    def extract_version_from_tag_name(tag_name)
      Fastlane::Helper::GitHelper.extract_version_from_tag_name(tag_name)
    end
  end

  describe "#extract_version_from_branch_name" do
    it "returns the version" do
      expect(extract_version_from_branch_name("main")).to be_nil
      expect(extract_version_from_branch_name("feature/test")).to be_nil
      expect(extract_version_from_branch_name("release/1.2.3")).to eq("1.2.3")
      expect(extract_version_from_branch_name("release/ios/1.2.3")).to eq("1.2.3")
      expect(extract_version_from_branch_name("release/macos/1.2.3")).to eq("1.2.3")
      expect(extract_version_from_branch_name("release/macos/some-text")).to be_nil
      expect(extract_version_from_branch_name("release/macos/1.2")).to be_nil
    end

    def extract_version_from_branch_name(branch_name)
      Fastlane::Helper::GitHelper.extract_version_from_branch_name(branch_name)
    end
  end

  describe "#validate_semver" do
    it "validates semantic version" do
      expect(validate_semver("1.0.0")).to be_truthy
      expect(validate_semver("0.0.0")).to be_truthy
      expect(validate_semver("7.136.1")).to be_truthy

      expect(validate_semver("v1.0.0")).to be_falsy
      expect(validate_semver("7.1")).to be_falsy
      expect(validate_semver("1.105.0-251")).to be_falsy
      expect(validate_semver("1005")).to be_falsy
    end

    def validate_semver(version)
      Fastlane::Helper::GitHelper.validate_semver(version)
    end
  end

  describe "#latest_release" do
    subject { Fastlane::Helper::GitHelper.latest_release(repo_name, prerelease, platform, github_token, allow_drafts: allow_drafts) }
    let(:allow_drafts) { false }

    include_context "common setup"

    context "when no releases matching platform are found" do
      let(:platform) { "ios" }
      let(:prerelease) { false }

      before do
        allow(client).to receive(:releases).with(repo_name, per_page: 25, page: 1).and_return(
          [
            double(tag_name: "2.0.0+macos", prerelease: false),
            double(tag_name: "1.0.0+macos", prerelease: false)
          ]
        )
      end

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when platform is not provided" do
      let(:platform) { nil }

      context "and prerelease is true" do
        let(:prerelease) { true }

        before do
          allow(client).to receive(:releases).with(repo_name, per_page: 25, page: 1).and_return(
            [
              double(tag_name: "1.2.3-4", prerelease: true),
              double(tag_name: "1.2.2-3", prerelease: true),
              double(tag_name: "1.2.3", prerelease: false)
            ]
          )
        end

        it "returns the latest prerelease" do
          expect(subject.tag_name).to eq("1.2.3-4")
        end
      end

      context "and prerelease is false" do
        let(:prerelease) { false }

        before do
          allow(client).to receive(:releases).with(repo_name, per_page: 25, page: 1).and_return(
            [
              double(tag_name: "2.0.0-1", prerelease: true),
              double(tag_name: "1.0.0", prerelease: false),
              double(tag_name: "1.0.0-1", prerelease: true)
            ]
          )
        end

        it "returns the latest full release" do
          expect(subject.tag_name).to eq("1.0.0")
        end
      end
    end

    context "when platform is provided" do
      let(:platform) { "ios" }

      context "and prerelease is true" do
        let(:prerelease) { true }

        before do
          allow(client).to receive(:releases).with(repo_name, per_page: 25, page: 1).and_return(
            [
              double(tag_name: "2.0.0+ios", prerelease: false),
              double(tag_name: "1.0.0-1+macos", prerelease: true),
              double(tag_name: "2.0.0-1+ios", prerelease: true),
              double(tag_name: "1.0.0-1+ios", prerelease: true)
            ]
          )
        end

        it "returns the latest prerelease with the platform suffix" do
          expect(subject.tag_name).to eq("2.0.0-1+ios")
        end
      end

      context "and prerelease is false" do
        let(:prerelease) { false }

        before do
          allow(client).to receive(:releases).with(repo_name, per_page: 25, page: 1).and_return(
            [
              double(tag_name: "1.1.0-0+ios", prerelease: true),
              double(tag_name: "1.0.0+macos", prerelease: false),
              double(tag_name: "1.0.0+ios", prerelease: false),
              double(tag_name: "1.0.0-1+ios", prerelease: true)
            ]
          )
        end

        it "returns the latest full release with the platform suffix" do
          expect(subject.tag_name).to eq("1.0.0+ios")
        end
      end
    end

    context "when allow_drafts is true" do
      let(:allow_drafts) { true }
      let(:platform) { "ios" }

      context "and prerelease is false" do
        let(:prerelease) { false }

        before do
          allow(client).to receive(:releases).with(repo_name, per_page: 25, page: 1).and_return(
            [
              double(tag_name: "2.0.0+ios", prerelease: false, draft: true),
              double(tag_name: "2.0.0-1+ios", prerelease: true),
              double(tag_name: "2.0.0-1+ios", prerelease: true),
              double(tag_name: "1.0.0+ios", prerelease: false)
            ]
          )
        end

        it "returns the latest public release that is a draft" do
          expect(subject.tag_name).to eq("2.0.0+ios")
        end
      end
    end
  end

  describe "#delete_release" do
    subject { Fastlane::Helper::GitHelper.delete_release(release_url, github_token) }
    let(:release_url) { "https://api.github.com/repos/duckduckgo/apple-browsers/releases/1234567890" }

    include_context "common setup"

    before do
      allow(client).to receive(:delete_release)
    end

    it "deletes the release" do
      subject
      expect(client).to have_received(:delete_release).with(release_url)
    end
  end

  describe "#assert_branch_has_changes" do
    subject { Fastlane::Helper::GitHelper.assert_branch_has_changes("release_branch", platform) }

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

        expect(subject).to be_falsey
        expect(Fastlane::UI).to have_received(:important).with("Release branch's HEAD is already tagged. Skipping automatic release.")
      end
    end

    context "when the release branch has changes since the latest tag" do
      it "returns true" do
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git tag --sort=-v:refname | grep '+#{platform}' | head -n 1").and_return("#{version}\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git rev-parse \"#{version}\"^{}").and_return("abc123\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with('git rev-parse "origin/release_branch"').and_return("def456\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git diff --name-only \"#{version}\"..\"origin/release_branch\"").and_return("app/file1.rb\napp/file2.rb\n")
        expect(subject).to be_truthy
      end
    end

    context "when changes are only in scripts or workflows" do
      it "returns false" do
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git tag --sort=-v:refname | grep '+#{platform}' | head -n 1").and_return("#{version}\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git rev-parse \"#{version}\"^{}").and_return("abc123\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with('git rev-parse "origin/release_branch"').and_return("def456\n")
        allow(Fastlane::Helper::GitHelper).to receive(:`).with("git diff --name-only \"#{version}\"..\"origin/release_branch\"").and_return(".github/workflows/workflow.yml\nscripts/deploy.sh\nfastlane/Fastfile\n")
        expect(subject).to be_falsey
      end
    end
  end

  describe "#untagged_commit_sha" do
    subject { Fastlane::Helper::GitHelper.untagged_commit_sha("release_branch", platform) }

    let (:platform) { "ios" }

    before do
      allow(Fastlane::Helper::GitHelper).to receive(:release_branch_state).and_return(
        is_tagged: is_tagged,
        release_branch_sha: "abc123"
      )
    end

    context "when the release branch is tagged" do
      let (:is_tagged) { true }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when the release branch has changes since the latest tag" do
      let (:is_tagged) { false }

      it "returns the untagged commit sha" do
        expect(subject).to eq("abc123")
      end
    end
  end
end
