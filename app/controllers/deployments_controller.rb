class DeploymentsController < ApplicationController
  before_filter :redirect_if_read_only_user, only: [:new, :create]

  def recent
    @deployments = Deployment.includes(:application).recent
  end

  def new
    default_deploy_time = Time.zone.now.strftime("%e/%m/%Y %H:%M")
    @deployment = Deployment.new(application_id: deployment_params[:application_id], environment: deployment_params[:environment], created_at: default_deploy_time)
  end

  def create
    if push_notification?
      application = application_by_repo
      application.archived = false
      application.save!
      Deployment.create!(deployment_params.merge(application: application))
      head 200
    else
      @deployment = Deployment.new(deployment_params)
      if @deployment.save
        application = Application.find(deployment_params[:application_id])
        application.archived = false
        application.save!
        redirect_to applications_path, notice: "Deployment created for #{application.name}"
      else
        flash[:alert] = "Failed to create deployment"
        render :new
      end
    end
  end

  private
    def application_by_repo
      if existing_app = Application.find_by_repo(repo_path)
        existing_app
      else
        Application.create!(name: app_name, repo: repo_path, domain: domain)
      end
    end

    def repo_path
      if params[:repo].start_with?("http")
        URI.parse(params[:repo]).path.gsub(%r{^/}, "")
      elsif params[:repo].start_with?("git@")
        params[:repo].split(":")[-1].gsub(/.git$/, "")
      else
        params[:repo]
      end
    end

    def app_name
      repo_title = repo_path.split("/")[-1].gsub("-", " ").humanize.titlecase
      repo_title.gsub(/\bApi\b/, "API")
    end

    def domain
      # Deployments created from push notifications will default to github.com
      "github.com"
    end

    def push_notification?
      params[:repo].present?
    end

    def deployment_params
      params.require(:deployment).permit(:id, :version, :environment, :application, :application_id, :created_at, :repo)
    end
end
