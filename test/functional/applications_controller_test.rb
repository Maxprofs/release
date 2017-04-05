require "test_helper"

class ApplicationsControllerTest < ActionController::TestCase
  setup do
    login_as_stub_user
  end

  context "GET index" do
    setup do
      @app1 = FactoryGirl.create(:application, name: "app1", repo: "user/app1")
      @app2 = FactoryGirl.create(:application, name: "app2", repo: "user/app2")
      @app3 = FactoryGirl.create(:application, name: "app3", repo: "user/app3", archived: true)
      @deploy1 = FactoryGirl.create(:deployment,
        application: @app1,
        environment: "staging",
        version: "release_x")
    end

    should "list unarchived applications" do
      get :index
      assert_select "table tbody tr", count: 2
    end

    should "show the latest deploy to an environment" do
      get :index
      assert_select "table tbody tr td:nth-child(3)", /release_x/
    end

    should "provide a link to compare with master" do
      get :index
      assert_select "table a[href=?]", "https://mygithub.tld/user/app1/compare/release_x...master"
    end

    should "provide a title attribute to sort environment columns by date" do
      get :index
      assert_select "table td[title=?]", @deploy1.created_at.to_s
    end

    context "when the user has no deploy permissions" do
      setup do
        login_as_read_only_stub_user
        get :index
      end

      should "not show buttons to add missing deployments" do
        assert_select "a:match('href', ?)", %r"/applications/\d+/deployments/new.*", count: 0
      end

      should "not show buttons to edit application notes" do
        assert_select "a:match('href', ?)", %r"#edit-notes-app-\d+", count: 0
      end

      should "not show button to create application" do
        assert_select "a[href='/applications/new']", false
      end
    end
  end

  context "GET new" do
    should "render the form" do
      get :new
      assert_select "form input#application_name"
    end
    should "redirect when the user has no deploy permissions" do
      actions_requiring_deploy_permission_redirect(:get, :new)
    end
  end

  context "POST create" do
    should "redirect when the user has no deploy permissions" do
      actions_requiring_deploy_permission_redirect(
        :post,
        :create,
        name: "My First App",
        repo: "org/my_first_app",
        domain: "github.baz"
      )
    end

    should "create an application" do
      assert_difference "Application.count", 1 do
        post :create, params: {
          application: {
            name: "My First App",
            repo: "org/my_first_app",
            domain: "github.baz"
          }
        }
      end
    end

    context "invalid request" do
      should "rerender the form" do
        post :create, params: { application: { name: "", repo: "org/my_first_app" } }
        assert_select "form input#application_name"
        assert_select "form input#application_repo[value='org/my_first_app']"
      end
    end
  end

  context "GET show" do
    setup do
      @app = FactoryGirl.create(:application)
      stub_request(:get, "https://api.github.com/repos/#{@app.repo}/tags").to_return(body: [])
      stub_request(:get, "https://api.github.com/repos/#{@app.repo}/commits").to_return(body: [])
    end

    should "show the application" do
      get :show, params: { id: @app.id }
      assert_select "h1 span.name", @app.name
    end

    should "should include status notes as a warning" do
      @app.update_attributes(status_notes: 'Do not deploy this without talking to core team first!')
      get :show, params: { id: @app.id }
      assert_select '.alert-warning', 'Do not deploy this without talking to core team first!'
    end

    context "GET show with a production deployment" do
      setup do
        version = "release_42"
        FactoryGirl.create(:deployment, application: @app, version: version)
        @first_commit = stub_commit
        @second_commit = stub_commit
        @base_commit = stub_commit
        Octokit::Client.any_instance.stubs(:compare)
          .with(@app.repo, version, "master")
          .returns(stub("comparison",
                        commits: [@first_commit, @second_commit],
                        base_commit: @base_commit))
      end

      should "show the application" do
        get :show, params: { id: @app.id }
        assert_select "h1 span.name", @app.name
      end

      should "set the commit history in reverse order" do
        get :show, params: { id: @app.id }

        # `assigns` in Rails silently converts hashes to
        # HashWithIndifferentAccess instances, so we can't simply compare for
        # equality on the objects themselves
        assert_equal(
          [@second_commit[:sha], @first_commit[:sha]],
          assigns[:commits].take(2).map { |commit| commit[:sha] }
        )
      end

      should "include the base commit" do
        get :show, params: { id: @app.id }

        assert_equal @base_commit[:sha], assigns[:commits].last[:sha]
      end
    end

    context "when the user has no deploy permissions" do
      setup do
        login_as_read_only_stub_user
        get :show, params: { id: @app.id }
      end

      should "not show the edit button" do
        assert_select "a[href='/applications/#{@app.id}/edit']", false
      end

      should "not show the button to record a missing deployment" do
        assert_select "a[href='/applications/#{@app.id}/deployments/new']", false
      end
    end

    context "when there is a github API 404 error" do
      setup do
        stub_request(:get, "https://api.github.com/repos/#{@app.repo}/tags").to_raise(Octokit::NotFound.new)
        get :show, params: { id: @app.id }
      end

      should "show the error message" do
        assert_select '.alert-error' do
          assert_select 'div', "Couldn't get data from GitHub:"
          assert_select 'div', "Octokit::NotFound"
        end
      end
    end

    context "when there is a github rate limit error" do
      setup do
        stub_request(:get, "https://api.github.com/repos/#{@app.repo}/tags").to_raise(Octokit::TooManyRequests.new)
        stub_request(:get, "https://api.github.com/rate_limit").to_return(
          headers: { "X-RateLimit-Reset" => 5.minutes.from_now.to_i },
          body: ""
        )
        get :show, params: { id: @app.id }
      end

      should "show the rate limit message" do
        assert_select '.alert-error' do
          assert_select 'div', "Couldn't get data from GitHub:"
          assert_select 'div', "Github API rate limit exceeded. Rate limit will reset in 5 minutes."
        end
      end
    end
  end

  context "GET edit" do
    setup do
      @app = FactoryGirl.create(:application, name: "monkeys", repo: "org/monkeys")
    end

    should "redirect when the user has no deploy permissions" do
      actions_requiring_deploy_permission_redirect(
        :get,
        :edit,
        id: 123
      )
    end

    should "show the form" do
      get :edit, params: { id: @app.id }
      assert_select "form input#application_name[value='#{@app.name}']"
    end

    should "allow editing of the shortname in the form" do
      get :edit, params: { id: @app.id }
      assert_select "form input#application_shortname[placeholder='#{@app.shortname}']"
    end
  end

  context "PUT update" do
    should "redirect when the user has no deploy permissions" do
      actions_requiring_deploy_permission_redirect(
        :get,
        :update,
        id: 456, application: { name: "new name", repo: "new/repo" }
      )
    end

    setup do
      @app = FactoryGirl.create(:application)
    end

    should "update the application" do
      put :update, params: { id: @app.id, application: { name: "new name", repo: "new/repo" } }
      @app.reload
      assert_equal "new name", @app.name
    end

    context "invalid request" do
      should "rerender the form" do
        put :update, params: { id: @app.id, application: { name: "", repo: "new/repo" } }
        @app.reload
        assert_select "form input#application_name[value='']"
        assert_select "form input#application_repo[value='new/repo']"
      end
    end
  end

  context "PUT update_notes" do
    should "redirect when the user has no deploy permissions" do
      actions_requiring_deploy_permission_redirect(
        :put,
        :update_notes,
        id: 789, application: { status_notes: "Rolled back deploy because science." }
      )
    end

    setup do
      @app = FactoryGirl.create(:application)
    end

    should "update the application, redirect to /applications" do
      put :update_notes, params: { id: @app.id, application: { status_notes: "Rolled back deploy because science." } }
      @app.reload
      assert_equal "Rolled back deploy because science.", @app.status_notes
      assert_redirected_to "/applications"
    end
  end

  context "GET archived" do
    setup do
      @app1 = FactoryGirl.create(:application, name: "app1", repo: "user/app1")
      @app2 = FactoryGirl.create(:application, name: "app2", repo: "user/app2")
      @app3 = FactoryGirl.create(:application, name: "app3", repo: "user/app3", archived: true)
    end

    should "show only archived applications" do
      get :archived
      assert_select "table tbody tr", count: 1
    end

    context "when the user has no deploy permissions" do
      setup do
        login_as_read_only_stub_user
        get :archived
      end

      should "not show buttons to add missing deployments" do
        assert_select "a:match('href', ?)", %r"/applications/\d+/deployments/new.*", count: 0
      end

      should "not show buttons to edit application notes" do
        assert_select "a:match('href', ?)", %r"#edit-notes-app-\d+", count: 0
      end
    end
  end

  context "GET deploy" do
    setup do
      @app = FactoryGirl.create(:application, status_notes: 'Do not deploy this without talking to core team first!')
      @deployment = FactoryGirl.create(:deployment, application_id: @app.id)
      @release_tag = 'hot_fix_1'
      stub_request(:get, "https://api.github.com/repos/#{@app.repo}/tags").to_return(body: [])
      stub_request(:get, "https://api.github.com/repos/#{@app.repo}/commits").to_return(body: [])
      Octokit::Client.any_instance.stubs(:compare)
        .with(@app.repo, @deployment.version, @release_tag)
        .returns(stub("comparison",
                      commits: [],
                      base_commit: nil))
    end

    should "show that we are trying to deploy the application" do
      get :deploy, params: { id: @app.id, tag: @release_tag }
      assert_select "h1 span.name", "Deploy #{@app.name}"
    end

    should "indicate which releases are current and about to be deployed" do
      get :deploy, params: { id: @app.id, tag: @release_tag }
      assert_select "h2 .label-info", @release_tag
      assert_select "p.lead .label-danger", @deployment.version
    end

    should "include status notes as a warning" do
      get :deploy, params: { id: @app.id, tag: @release_tag }
      assert_select '.alert-warning', 'Do not deploy this without talking to core team first!'
    end

    should "show dashboard links when application is Whitehall" do
      @app.shortname = "whitehall"
      @app.save

      get :deploy, params: { id: @app.id, tag: @release_tag }
      assert_select "a[href=?]", "https://grafana.publishing.service.gov.uk/dashboard/db/prototype-dashboard-whitehall"
      assert_select "a[href=?]", "https://grafana.staging.publishing.service.gov.uk/dashboard/db/prototype-dashboard-whitehall"
    end

    should "not show dashboard links for other applications" do
      @app.shortname = "test_application"
      @app.save

      get :deploy, params: { id: @app.id, tag: @release_tag }
      assert_select "a:match('href', ?)", %r"grafana.publishing.service.gov.uk", count: 0
      assert_select "a:match('href', ?)", %r"grafana.staging.publishing.service.gov.uk", count: 0
    end
  end

private

  def random_sha
    hex_chars = Enumerator.new do |yielder|
      loop { yielder << "0123456789abcdef".chars.to_a.sample }
    end
    hex_chars.take(40).join
  end

  def stub_commit
    {
      sha: random_sha,
      login: "winston",
      commit: {
        message: "Hi"
      }
    }
  end
end
