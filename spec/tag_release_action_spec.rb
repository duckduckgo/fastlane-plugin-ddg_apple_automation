shared_context "common setup" do
  before do
    @params = {
      asana_access_token: "asana-token",
      asana_task_url: "https://app.asana.com/0/0/1/f",
      ignore_untagged_commits: false,
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
    @tag = "1.1.0-123+macos"
    @promoted_tag = nil
    allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:compute_tag).and_return([@tag, @promoted_tag])
  end
end

shared_context "for public release" do
  before do
    @params[:is_prerelease] = false
    @tag = "1.1.0+macos"
    @promoted_tag = "1.1.0-123+macos"
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
      allow(Fastlane::Actions::TagReleaseAction).to receive(:assert_branch_tagged_before_public_release).and_return(true)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:create_tag_and_github_release).and_return(@tag_and_release_output)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:merge_or_delete_branch)
      allow(Fastlane::Actions::TagReleaseAction).to receive(:report_status)
    end

    context "when tag is created" do
      before do
        @tag_and_release_output[:tag_created] = true
      end

      it "creates tag and release, merges tag and reports status" do
        subject
        expect(@tag_and_release_output[:merge_or_delete_successful]).to be_truthy
      end
    end

    context "when tag is not created" do
      before do
        @tag_and_release_output[:tag_created] = false
      end

      shared_examples "reporting failure" do
        it "reports failure" do
          subject
          expect(Fastlane::Actions::TagReleaseAction).to have_received(:report_status).with(hash_including(tag_created: false))
        end
      end

      context "for prerelease" do
        include_context "for prerelease"
        it_behaves_like "reporting failure"
      end

      context "for public release" do
        include_context "for public release"
        it_behaves_like "reporting failure"
      end
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

    context "when branch is not tagged before public release" do
      before do
        allow(Fastlane::Actions::TagReleaseAction).to receive(:assert_branch_tagged_before_public_release).and_return(false)
        allow(Fastlane::UI).to receive(:important)
        allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
      end

      it "stops the workflow" do
        subject
        expect(Fastlane::UI).to have_received(:important).with("Skipping release because release branch's HEAD is not tagged.")
        expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("stop_workflow", true)
        expect(Fastlane::Actions::TagReleaseAction).not_to have_received(:report_status)
      end
    end
  end

  describe "#create_tag_and_github_release" do
    let(:platform) { "macos" }
    subject { Fastlane::Actions::TagReleaseAction.create_tag_and_github_release(@params[:is_prerelease], platform, @params[:github_token]) }

    let (:latest_public_release) { double(tag_name: "1.0.0+macos", prerelease: false) }
    let (:generated_release_notes) { { body: { "name" => "1.1.0", "body" => "Release notes" } } }
    let (:other_action) { double(add_git_tag: nil, push_git_tags: nil, github_api: generated_release_notes, set_github_release: nil) }
    let (:commit_sha_for_tag) { "promoted-tag-sha" }

    shared_context "local setup" do
      before(:each) do
        allow(Fastlane::Helper::GitHelper).to receive(:latest_release).and_return(latest_public_release)
        allow(JSON).to receive(:parse).and_return(generated_release_notes[:body])
        allow(Fastlane::Action).to receive(:other_action).and_return(other_action)
        allow(Fastlane::UI).to receive(:message)
        allow(Fastlane::UI).to receive(:important)
        allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:report_error)
        allow(Fastlane::Helper::GitHelper).to receive(:commit_sha_for_tag).and_return(commit_sha_for_tag)
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
        if @params[:is_prerelease]
          expect(other_action).to have_received(:add_git_tag).with(tag: @tag)
        else
          expect(Fastlane::Helper::GitHelper).to have_received(:commit_sha_for_tag).with(@promoted_tag)
          expect(other_action).to have_received(:add_git_tag).with(tag: @tag, commit: commit_sha_for_tag)
        end
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
              latest_public_release_tag: latest_public_release.tag_name,
              tag: @tag,
              promoted_tag: @promoted_tag,
              tag_created: false
            })
        expect(Fastlane::UI).to have_received(:important).with("Failed to create and push tag")
        expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:report_error).with(StandardError)
      end
    end

    shared_examples "gracefully handling GitHub release error" do
      it "handles GitHub release error" do
        expect(subject).to eq({
              tag: @tag,
              promoted_tag: @promoted_tag,
              tag_created: true,
              latest_public_release_tag: latest_public_release.tag_name
            })
        expect(Fastlane::UI).to have_received(:important).with("Failed to create GitHub release")
        expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:report_error).with(StandardError)
      end
    end

    platform_contexts = [
      { name: "on ios", repo_name: "duckduckgo/apple-browsers" },
      { name: "on macos", repo_name: "duckduckgo/apple-browsers" }
    ]
    release_type_contexts = ["for prerelease", "for public release"]
    tag_contexts = ["when failed to create tag", "when failed to push tag"]
    github_release_contexts = [
      "when failed to generate GitHub release notes",
      "when failed to parse GitHub response",
      "when failed to create GitHub release"
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
              context github_release_context do
                include_context github_release_context
                it_behaves_like "gracefully handling GitHub release error"
              end
            end
          end
        end
      end
    end
  end

  describe "#merge_or_delete_branch" do
    subject { Fastlane::Actions::TagReleaseAction.merge_or_delete_branch(@params) }

    let (:branch) { "release/1.1.0" }
    let (:other_action) { double(git_branch: branch) }

    platform_contexts = [
      { name: "on ios", repo_name: "duckduckgo/apple-browsers" },
      { name: "on macos", repo_name: "duckduckgo/apple-browsers" }
    ]

    include_context "common setup"

    before do
      @params[:base_branch] = "base_branch"
      @params[:tag] = "1.1.0-123+macos"
      allow(Fastlane::Action).to receive(:other_action).and_return(other_action)
      allow(Fastlane::Helper::GitHelper).to receive(:merge_branch)
      allow(Fastlane::Helper::GitHelper).to receive(:delete_branch)
    end

    platform_contexts.each do |platform_context|
      context platform_context[:name] do
        include_context platform_context[:name]

        context "for prerelease" do
          include_context "for prerelease"

          it "merges tag to base branch" do
            subject
            expect(Fastlane::Helper::GitHelper).to have_received(:merge_branch)
              .with(platform_context[:repo_name], @params[:tag], @params[:base_branch], @params[:github_token])
          end

          it "uses elevated permissions GitHub token if provided" do
            @params[:github_elevated_permissions_token] = "elevated-permissions-token"
            subject
            expect(Fastlane::Helper::GitHelper).to have_received(:merge_branch)
              .with(platform_context[:repo_name], @params[:tag], @params[:base_branch], @params[:github_elevated_permissions_token])
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
      { name: "on ios", repo_name: "duckduckgo/apple-browsers" },
      { name: "on macos", repo_name: "duckduckgo/apple-browsers" }
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

  describe Fastlane::Actions::TagReleaseAction do
    describe ".template_arguments" do
      let(:params) do
        {
          base_branch: "develop",
          tag: "1.123.0-321+macos",
          promoted_tag: "1.123.0-321",
          tag_created: false,
          latest_public_release_tag: "1.122.0",
          platform: "macos",
          is_prerelease: true
        }
      end

      let(:constants) do
        {
          repo_name: "org/repo",
          dmg_url_prefix: "https://example.com/"
        }
      end

      before do
        allow(Fastlane::Action).to receive(:other_action).and_return(double(git_branch: "feature-branch"))
        Fastlane::Actions::TagReleaseAction.instance_variable_set(:@constants, constants)
      end

      it "returns correct template arguments for macOS release" do
        expected_result = {
          "base_branch" => "develop",
          "branch" => "feature-branch",
          "tag" => "1.123.0-321+macos",
          "promoted_tag" => "1.123.0-321",
          "release_url" => "https://github.com/org/repo/releases/tag/1.123.0-321+macos",
          "last_release_tag" => "1.122.0",
          "dmg_url" => "https://example.com/duckduckgo-1.123.0.321.dmg"
        }

        result = Fastlane::Actions::TagReleaseAction.template_arguments(params)
        expect(result).to eq(expected_result)
      end

      it "omits last_release_tag if tag_created is true" do
        params[:tag_created] = true
        result = Fastlane::Actions::TagReleaseAction.template_arguments(params)

        expect(result).not_to have_key("last_release_tag")
      end

      it "handles prerelease version correctly" do
        expected_dmg_url = "https://example.com/duckduckgo-1.123.0.321.dmg"

        result = Fastlane::Actions::TagReleaseAction.template_arguments(params)
        expect(result["dmg_url"]).to eq(expected_dmg_url)
      end
    end
  end
end
