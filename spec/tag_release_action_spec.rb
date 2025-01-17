shared_context "common setup" do
  before do
    @params = {
      asana_access_token: "asana-token",
      asana_task_url: "https://app.asana.com/0/0/1/f",
      is_prerelease: true,
      github_token: "github-token"
    }
    @tag_and_release_output = {}
    allow(Fastlane::Helper).to receive(:setup_git_user)
  end
end

shared_context "on ios" do
  before do
    @params[:platform] = "ios"
    Fastlane::Actions::TagReleaseAction.setup_constants(@params[:platform])
  end
end

shared_context "on macos" do
  before do
    @params[:platform] = "macos"
    Fastlane::Actions::TagReleaseAction.setup_constants(@params[:platform])
  end
end

shared_context "for prerelease" do
  before do
    @params[:is_prerelease] = true
    @tag = "1.1.0-123"
    @promoted_tag = nil
    allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:compute_tag).and_return([@tag, @promoted_tag])
  end
end

shared_context "for public release" do
  before do
    @params[:is_prerelease] = false
    @tag = "1.1.0"
    @promoted_tag = "1.1.0-123"
    allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:compute_tag).and_return([@tag, @promoted_tag])
  end
end

shared_context "when merge_or_delete_successful: true" do
  before { @params[:merge_or_delete_successful] = true }
end

shared_context "when merge_or_delete_successful: false" do
  before { @params[:merge_or_delete_successful] = false }
end

shared_context "when is_prerelease: true" do
  before { @params[:is_prerelease] = true }
end

shared_context "when is_prerelease: false" do
  before { @params[:is_prerelease] = false }
end

shared_context "when tag_created: true" do
  before { @params[:tag_created] = true }
end

shared_context "when tag_created: false" do
  before { @params[:tag_created] = false }
end

describe Fastlane::Actions::TagReleaseAction do
  describe "#run" do
    subject do
      configuration = Fastlane::ConfigurationHelper.parse(Fastlane::Actions::TagReleaseAction, @params)
      Fastlane::Actions::TagReleaseAction.run(configuration)
    end

    include_context "common setup"

    before do
      @other_action = double(ensure_git_branch: nil)
      allow(Fastlane::Action).to receive(:other_action).and_return(@other_action)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:create_tag_and_github_release).and_return(@tag_and_release_output)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:merge_or_delete_branch)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:report_status)
    end

    it "creates tag and release, merges branch and reports status" do
      subject

      expect(@tag_and_release_output[:merge_or_delete_successful]).to be_truthy
    end

    context "when merge or delete failed" do
      before do
        allow(Fastlane::Actions::TagReleaseAction).to receive(:merge_or_delete_branch).and_raise(StandardError)
      end

      it "reports status" do
        subject
        expect(@tag_and_release_output[:merge_or_delete_successful]).to be_falsy
      end
    end
  end

  describe "#create_tag_and_github_release" do
    subject { Fastlane::Actions::TagReleaseAction.create_tag_and_github_release(@params[:is_prerelease], @params[:github_token]) }

    let (:latest_public_release) { double(tag_name: "1.0.0") }
    let (:generated_release_notes) { { body: { "name" => "1.1.0", "body" => "Release notes" } } }
    let (:other_action) { double(add_git_tag: nil, push_git_tags: nil, github_api: generated_release_notes, set_github_release: nil) }
    let (:octokit_client) { double(latest_release: latest_public_release) }

    shared_context "local setup" do
      before(:each) do
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(JSON).to receive(:parse).and_return(generated_release_notes[:body])
        allow(Fastlane::Action).to receive(:other_action).and_return(other_action)
        allow(Fastlane::UI).to receive(:message)
        allow(Fastlane::UI).to receive(:important)
      end
    end

    shared_examples "successful execution" do |repo_name|
      let (:repo_name) { repo_name }

      it "creates tag and github release" do
        expect(subject).to eq({
              tag: @tag,
              promoted_tag: @promoted_tag,
              tag_created: true,
              latest_public_release_tag: latest_public_release.tag_name
            })

        expect(Fastlane::UI).to have_received(:message).with("Latest public release: #{latest_public_release.tag_name}").ordered
        expect(Fastlane::UI).to have_received(:message).with("Generating #{repo_name} release notes for GitHub release for tag: #{@tag}").ordered
        expect(other_action).to have_received(:add_git_tag).with(tag: @tag)
        expect(other_action).to have_received(:push_git_tags).with(tag: @tag)

        expect(other_action).to have_received(:github_api).with(
          api_bearer: @params[:github_token],
          http_method: "POST",
          path: "/repos/#{repo_name}/releases/generate-notes",
          body: {
            tag_name: @tag,
            previous_tag_name: latest_public_release.tag_name
          }
        )

        expect(JSON).to have_received(:parse).with(generated_release_notes[:body])

        expect(other_action).to have_received(:set_github_release).with(
          repository_name: repo_name,
          api_bearer: @params[:github_token],
          tag_name: @tag,
          name: generated_release_notes[:body]["name"],
          description: generated_release_notes[:body]["body"],
          is_prerelease: @params[:is_prerelease]
        )
        expect(Fastlane::UI).not_to have_received(:important)
      end
    end

    shared_context "when failed to create tag" do
      before do
        allow(other_action).to receive(:add_git_tag).and_raise(StandardError)
      end
    end

    shared_context "when failed to push tag" do
      before do
        allow(other_action).to receive(:push_git_tags).and_raise(StandardError)
      end
    end

    shared_context "when failed to fetch latest GitHub release" do
      before do
        allow(octokit_client).to receive(:latest_release).and_raise(StandardError)
      end
    end

    shared_context "when failed to generate GitHub release notes" do
      before do
        allow(other_action).to receive(:github_api).and_raise(StandardError)
      end
    end

    shared_context "when failed to parse GitHub response" do
      before do
        allow(JSON).to receive(:parse).and_raise(StandardError)
      end
    end

    shared_context "when failed to create GitHub release" do
      before do
        allow(other_action).to receive(:set_github_release).and_raise(StandardError)
      end
    end

    shared_examples "gracefully handling tagging error" do
      it "handles tagging error" do
        expect(subject).to eq({
              tag: @tag,
              promoted_tag: @promoted_tag,
              tag_created: false
            })
        expect(Fastlane::UI).to have_received(:important).with("Failed to create and push tag: StandardError")
      end
    end

    shared_examples "gracefully handling GitHub release error" do |reports_latest_public_release_tag|
      let (:reports_latest_public_release_tag) { reports_latest_public_release_tag }

      it "handles GitHub release error" do
        expect(subject).to eq({
              tag: @tag,
              promoted_tag: @promoted_tag,
              tag_created: true,
              latest_public_release_tag: reports_latest_public_release_tag ? latest_public_release.tag_name : nil
            })
        expect(Fastlane::UI).to have_received(:important).with("Failed to create GitHub release: StandardError")
      end
    end

    platform_contexts = [
      { name: "on ios", repo_name: "duckduckgo/ios" },
      { name: "on macos", repo_name: "duckduckgo/macos-browser" }
    ]
    release_type_contexts = ["for prerelease", "for public release"]
    tag_contexts = ["when failed to create tag", "when failed to push tag"]
    github_release_contexts = [
      { name: "when failed to fetch latest GitHub release", includes_latest_public_release_tag: false },
      { name: "when failed to generate GitHub release notes", includes_latest_public_release_tag: true },
      { name: "when failed to parse GitHub response", includes_latest_public_release_tag: true },
      { name: "when failed to create GitHub release", includes_latest_public_release_tag: true }
    ]

    include_context "common setup"
    include_context "local setup"

    platform_contexts.each do |platform_context|
      context platform_context[:name] do
        include_context platform_context[:name]

        release_type_contexts.each do |release_type_context|
          context release_type_context do
            include_context release_type_context
            it_behaves_like "successful execution", platform_context[:repo_name]

            tag_contexts.each do |tag_context|
              context tag_context do
                include_context tag_context
                it_behaves_like "gracefully handling tagging error"
              end
            end

            github_release_contexts.each do |github_release_context|
              context github_release_context[:name] do
                include_context github_release_context[:name]
                it_behaves_like "gracefully handling GitHub release error", github_release_context[:includes_latest_public_release_tag]
              end
            end
          end
        end
      end
    end
  end

  describe "#merge_or_delete_branch" do
    subject { Fastlane::Actions::TagReleaseAction.merge_or_delete_branch(@params) }

    let (:branch) { "release/ios/1.1.0" }
    let (:other_action) { double(git_branch: branch) }

    platform_contexts = [
      { name: "on ios", repo_name: "duckduckgo/ios" },
      { name: "on macos", repo_name: "duckduckgo/macos-browser" }
    ]

    include_context "common setup"

    before do
      @params[:base_branch] = "base_branch"
      allow(Fastlane::Action).to receive(:other_action).and_return(other_action)
      allow(Fastlane::Helper::GitHelper).to receive(:merge_branch)
      allow(Fastlane::Helper::GitHelper).to receive(:delete_branch)
    end

    platform_contexts.each do |platform_context|
      context platform_context[:name] do
        include_context platform_context[:name]

        context "for prerelease" do
          include_context "for prerelease"

          it "merges branch" do
            subject
            expect(other_action).to have_received(:git_branch)
            expect(Fastlane::Helper::GitHelper).to have_received(:merge_branch)
              .with(platform_context[:repo_name], branch, @params[:base_branch], @params[:github_token])
          end

          it "uses elevated permissions GitHub token if provided" do
            @params[:github_elevated_permissions_token] = "elevated-permissions-token"
            subject
            expect(other_action).to have_received(:git_branch)
            expect(Fastlane::Helper::GitHelper).to have_received(:merge_branch)
              .with(platform_context[:repo_name], branch, @params[:base_branch], @params[:github_elevated_permissions_token])
          end
        end

        context "for public release" do
          include_context "for public release"

          it "deletes branch" do
            subject
            expect(other_action).to have_received(:git_branch)
            expect(Fastlane::Helper::GitHelper).to have_received(:delete_branch)
              .with(platform_context[:repo_name], branch, @params[:github_token])
          end

          it "uses elevated permissions GitHub token if provided" do
            @params[:github_elevated_permissions_token] = "elevated-permissions-token"
            subject
            expect(other_action).to have_received(:git_branch)
            expect(Fastlane::Helper::GitHelper).to have_received(:delete_branch)
              .with(platform_context[:repo_name], branch, @params[:github_elevated_permissions_token])
          end
        end
      end
    end
  end

  describe "#report_status" do
    subject { Fastlane::Actions::TagReleaseAction.report_status(@params) }

    let (:task_template) { "task-template" }
    let (:comment_template) { "comment-template" }
    let (:created_task_id) { "12345" }
    let (:template_args) { {} }

    include_context "common setup"

    before do
      @params[:is_internal_release_bump] = false

      allow(Fastlane::Actions::TagReleaseAction).to receive(:template_arguments).and_return(template_args)
      allow(Fastlane::UI).to receive(:important)
      allow(Fastlane::Actions::AsanaCreateActionItemAction).to receive(:run).and_return(created_task_id)
      allow(Fastlane::Actions::AsanaLogMessageAction).to receive(:run)
    end

    shared_examples "logging a message without creating Asana task" do
      it "logs a message creating Asana task" do
        subject
        expect(Fastlane::Actions::TagReleaseAction).to have_received(:template_arguments).with(@params)
        expect(Fastlane::Actions::TagReleaseAction).to have_received(:setup_asana_templates).with(@params)
        expect(Fastlane::Actions::AsanaCreateActionItemAction).not_to have_received(:run)
        expect(Fastlane::Actions::AsanaLogMessageAction).to have_received(:run)
      end
    end

    shared_examples "creating Asana task and logging a message" do
      it "creates Asana task and logs a message" do
        subject
        expect(Fastlane::Actions::TagReleaseAction).to have_received(:template_arguments).with(@params)
        expect(Fastlane::Actions::TagReleaseAction).to have_received(:setup_asana_templates).with(@params)
        expect(Fastlane::Actions::AsanaCreateActionItemAction).to have_received(:run)
        expect(Fastlane::Actions::AsanaLogMessageAction).to have_received(:run)
        expect(template_args['task_id']).to eq(created_task_id)
      end
    end

    context "when task template is defined" do
      before do
        allow(Fastlane::Actions::TagReleaseAction).to receive(:setup_asana_templates).and_return([task_template, comment_template])
      end

      context "when internal release bump" do
        before { @params[:is_internal_release_bump] = true }

        context "on ios" do
          include_context "on ios"
          it_behaves_like "creating Asana task and logging a message"
        end

        context "on macos" do
          include_context "on macos"
          it_behaves_like "creating Asana task and logging a message"
        end
      end

      context "when not internal release bump" do
        before { @params[:is_internal_release_bump] = false }

        ["on ios", "on macos"].each do |platform_context|
          context platform_context do
            include_context platform_context
            it_behaves_like "creating Asana task and logging a message"
          end
        end
      end
    end

    context "when task template is not defined" do
      before do
        allow(Fastlane::Actions::TagReleaseAction).to receive(:setup_asana_templates).and_return([nil, comment_template])
      end

      context "when internal release bump" do
        before { @params[:is_internal_release_bump] = true }

        ["on ios", "on macos"].each do |platform_context|
          include_context platform_context
          it_behaves_like "logging a message without creating Asana task"
        end
      end

      context "when not internal release bump" do
        before { @params[:is_internal_release_bump] = false }

        ["on ios", "on macos"].each do |platform_context|
          context platform_context do
            include_context platform_context
            it_behaves_like "logging a message without creating Asana task"
          end
        end
      end
    end
  end

  describe "#template_arguments" do
    subject { Fastlane::Actions::TagReleaseAction.template_arguments(@params) }

    include_context "common setup"

    before do
      @params[:base_branch] = "base_branch"
      @params[:tag] = "1.1.0"
      @params[:promoted_tag] = "1.1.0-123"
      @params[:latest_public_release_tag] = "1.0.0"
      @params[:is_prerelease] = true
      allow(Fastlane::Action).to receive(:other_action).and_return(double(git_branch: "release/1.1.0"))
    end

    platform_contexts = [
      { name: "on ios", repo_name: "duckduckgo/ios" },
      { name: "on macos", repo_name: "duckduckgo/macos-browser" }
    ]

    shared_examples "populating tag, promoted_tag and release_url" do |repo_name|
      it "populates tag, promoted_tag and release_url when tag_created is true" do
        @params[:tag_created] = true
        expect(subject).to include({
          'base_branch' => @params[:base_branch],
          'branch' => "release/1.1.0",
          'tag' => @params[:tag],
          'promoted_tag' => @params[:promoted_tag],
          'release_url' => "https://github.com/#{repo_name}/releases/tag/#{@params[:tag]}"
        })
        expect(subject).not_to include("last_release_tag")
      end

      it "populates last_release_tag when tag_created is false" do
        @params[:tag_created] = false
        expect(subject).to include({
          'last_release_tag' => @params[:latest_public_release_tag]
        })
      end
    end

    platform_contexts.each do |platform_context|
      context platform_context[:name] do
        include_context platform_context[:name]
        it_behaves_like "populating tag, promoted_tag and release_url", platform_context[:repo_name]

        case platform_context[:name]
        when "on ios"
          it "does not populate dmg_url" do
            expect(subject).not_to include("dmg_url")
          end
        when "on macos"
          it "populates dmg_url using tag for prerelease" do
            @params[:is_prerelease] = true
            expect(subject).to include({
              'dmg_url' => "https://staticcdn.duckduckgo.com/macos-desktop-browser/duckduckgo-1.1.0.dmg"
            })
          end

          it "populates dmg_url using promoted tag for public release" do
            @params[:is_prerelease] = false
            expect(subject).to include({
              'dmg_url' => "https://staticcdn.duckduckgo.com/macos-desktop-browser/duckduckgo-1.1.0.123.dmg"
            })
          end
        end
      end
    end
  end

  describe "#setup_asana_templates" do
    subject { Fastlane::Actions::TagReleaseAction.setup_asana_templates(@params) }

    include_context "common setup"

    context "when merge_or_delete_successful: true" do
      include_context "when merge_or_delete_successful: true"

      context "when is_prerelase: true" do
        include_context "when is_prerelease: true"

        it "comment_template = internal-release-ready" do
          expect(subject).to eq([nil, "internal-release-ready"])
        end
      end

      context "when is_prerelase: false" do
        include_context "when is_prerelease: false"

        it "comment_template = public-release-tagged" do
          expect(subject).to eq([nil, "public-release-tagged"])
        end
      end
    end

    context "when merge_or_delete_successful: false" do
      include_context "when merge_or_delete_successful: false"

      context "when tag_created: true, is_prerelase = true" do
        include_context "when tag_created: true"
        include_context "when is_prerelease: true"

        it "task_template = merge-failed, comment_template = internal-release-ready-merge-failed" do
          expect(subject).to eq(["merge-failed", "internal-release-ready-merge-failed"])
        end
      end

      context "when tag_created: true, is_prerelase = false" do
        include_context "when tag_created: true"
        include_context "when is_prerelease: false"

        it "task_template = delete-branch-failed, comment_template = public-release-tagged-delete-branch-failed" do
          expect(subject).to eq(["delete-branch-failed", "public-release-tagged-delete-branch-failed"])
        end
      end

      context "when tag_created: false, is_prerelase = true" do
        include_context "when tag_created: false"
        include_context "when is_prerelease: true"

        it "task_template = internal-release-tag-failed, comment_template = internal-release-ready-tag-failed" do
          expect(subject).to eq(["internal-release-tag-failed", "internal-release-ready-tag-failed"])
        end
      end

      context "when tag_created: false, is_prerelase = false" do
        include_context "when tag_created: false"
        include_context "when is_prerelease: false"

        it "task_template = public-release-tag-failed, comment_template = public-release-tag-failed" do
          expect(subject).to eq(["public-release-tag-failed", "public-release-tag-failed"])
        end
      end
    end
  end
end
