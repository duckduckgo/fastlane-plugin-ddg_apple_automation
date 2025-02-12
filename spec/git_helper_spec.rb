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

  describe "#latest_release" do
    subject { Fastlane::Helper::GitHelper.latest_release(repo_name, prerelease, platform, github_token) }

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
  end
end
