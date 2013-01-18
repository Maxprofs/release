class Deployment < ActiveRecord::Base
  belongs_to :application

  attr_accessible :version, :environment, :application, :application_id, :created_at

  validates_presence_of :version, :environment, :application_id

  def self.environments
    Deployment.select('DISTINCT environment').map(&:environment)
  end

  def self.last_deploy_to(environment)
    where(environment: environment)
      .order("created_at DESC")
      .first
  end

  def previous_deployment
    @previous_deployment ||= Deployment
      .where(application_id: self.application.id, environment: self.environment)
      .order("created_at DESC")
      .offset(1)
      .first
  end

  def recent?
    created_at > 2.hours.ago
  end
end