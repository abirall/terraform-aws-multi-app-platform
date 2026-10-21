check "portfolio_service_route" {
  assert {
    condition     = try(local.service_routes[var.portfolio_service_route].target_group_port == var.portfolio_app_port, false)
    error_message = "portfolio_service_route must exist in service_routes and its target_group_port must match portfolio_app_port."
  }
}

module "ecr_portfolio" {
  source       = "./modules/ecr"
  project_name = var.project_name
  repo_name    = "${var.project_name}-portfolio-repo"
}

module "portfolio" {
  source = "./modules/app/portfolio"

  project_name    = var.project_name
  environment     = var.environment
  aws_region      = var.aws_region
  container_name  = "portfolio"
  container_image = "${module.ecr_portfolio.repository_url}:${var.portfolio_image_tag}"
  container_port  = var.portfolio_app_port
  cpu             = var.portfolio_cpu
  memory          = var.portfolio_memory
  desired_count   = var.portfolio_desired_count

  cluster_name         = module.ecs.cluster_name
  alb_target_group_arn = module.alb.target_group_arns[var.portfolio_service_route]
  log_retention_days   = var.log_retention_days
  tags                 = var.tags

  container_environment = {
    FLASK_APP  = var.portfolio_flask_app
    FLASK_ENV  = var.portfolio_flask_env
    PORT       = var.portfolio_app_port
    SECRET_KEY = var.portfolio_secret_key

    # Python reads these as strings, so keep the capitalized boolean spelling.
    EMAIL_HOST          = var.portfolio_email_host
    EMAIL_PORT          = var.portfolio_email_port
    EMAIL_HOST_USER     = var.portfolio_email_host_user
    EMAIL_HOST_PASSWORD = var.portfolio_email_host_password
    EMAIL_USE_SSL       = var.portfolio_email_use_ssl ? "True" : "False"
    EMAIL_USE_TLS       = var.portfolio_email_use_tls ? "True" : "False"

    MAIL_DEFAULT_SENDER = var.portfolio_mail_default_sender

    WEBSITE_HEALTHCHECK_MAXPINGFAILURES = var.portfolio_healthcheck_max_ping_failures

    DB_HOST     = aws_db_instance.postgres.address
    DB_PORT     = aws_db_instance.postgres.port
    DB_NAME     = var.portfolio_database_name
    DB_USER     = var.portfolio_database_username
    DB_PASSWORD = var.portfolio_database_password
  }
}
