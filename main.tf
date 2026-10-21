locals {
  service_routes = {
    for service_name, route in var.service_routes : service_name => {
      domains = distinct([
        for domain in route.domains : lower(trimsuffix(trimspace(domain), "."))
      ])
      target_group_port = route.target_group_port
      health_check_path = route.health_check_path
    }
  }
  website_domains = distinct(flatten([
    for route in values(local.service_routes) : route.domains
  ]))
}

check "lgm_service_route" {
  assert {
    condition     = try(local.service_routes[var.lgm_service_route].target_group_port == var.app_container_port, false)
    error_message = "lgm_service_route must exist in service_routes and its target_group_port must match app_container_port."
  }
}

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}


module "acm" {
  source                    = "./modules/acm"
  domain_name               = local.website_domains[0]
  subject_alternative_names = slice(local.website_domains, 1, length(local.website_domains))
}

module "alb" {
  source                     = "./modules/alb"
  project_name               = var.project_name
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  certificate_arn            = module.acm.certificate_arn
  service_routes             = local.service_routes
  enable_deletion_protection = var.enable_deletion_protection
  tags                       = var.tags
}

module "ecs" {
  source                = "./modules/ecs"
  project_name          = var.project_name
  environment           = var.environment
  ec2_instance_type     = var.ecs_instance_type
  vpc_id                = module.vpc.vpc_id
  alb_security_group_id = module.alb.alb_security_group_id
  subnet_ids            = module.vpc.private_subnet_ids
  min_capacity          = var.ecs_min_size
  max_capacity          = var.ecs_max_size
  desired_capacity      = var.ecs_desired_capacity
}

locals {
  lgm_domain = var.service_routes.lgm-web.domains[0]
}
module "lgm_web" {
  source = "./modules/app/lgm-web"

  project_name    = var.project_name
  environment     = var.environment
  aws_region      = var.aws_region
  container_name  = "lgm-web"
  container_image = "${module.ecr.repository_url}:${var.app_image_tag}"
  container_port  = var.app_container_port
  cpu             = var.app_cpu
  memory          = var.app_memory
  desired_count   = var.app_desired_count

  cluster_name         = module.ecs.cluster_name
  alb_target_group_arn = module.alb.target_group_arns[var.lgm_service_route]
  log_retention_days   = var.log_retention_days
  tags                 = var.tags


  container_environment = {
    # NODE_ENV                         = var.lgm_node_env
    # NODE_OPTIONS                     = var.lgm_node_options
    # PORT                             = var.lgm_app_port
    # NEXT_PUBLIC_API_URL              = var.lgm_next_public_api_url
    # NEXT_PUBLIC_APP_URL              = var.lgm_next_public_app_url
    # NEXTAUTH_URL                     = var.lgm_nextauth_url
    # NEXT_PUBLIC_FILE_SERVICE_URL     = var.lgm_next_public_file_service_url
    # NEXT_PUBLIC_FILE_SERVICE_USER_ID = var.lgm_next_public_file_service_user_id
    # NEXT_PUBLIC_FTP_DIR              = var.lgm_next_public_ftp_dir
    # NEXT_PUBLIC_FTP_HOST             = var.lgm_next_public_ftp_host

    NEXT_PUBLIC_APP_ENV             = var.lgm_node_env
    NEXT_PUBLIC_LIVE_URL            = "https://${local.lgm_domain}"
    NEXT_PUBLIC_APP_URL             = "https://${local.lgm_domain}"
    NEXT_PUBLIC_API_URL             = "https://${local.lgm_domain}/api"
    DATABASE_URL                    = "postgresql://${var.lgm_database_username}:${var.lgm_database_password}@${aws_db_instance.postgres.endpoint}/${var.lgm_database_name}?pgbouncer=true"
    DIRECT_URL                      = "postgresql://${var.lgm_database_username}:${var.lgm_database_password}@${aws_db_instance.postgres.endpoint}/${var.lgm_database_name}"
    NEXTAUTH_SECRET                 = var.lgm_nextauth_secret
    NEXTAUTH_URL                    = "https://${local.lgm_domain}"
    EMAIL_SERVER_HOST               = "smtp.gmail.com"
    EMAIL_SERVER_PORT               = 587
    EMAIL_SERVER_USER               = "vanilla.sooft@gmail.com"
    EMAIL_SERVER_PASSWORD = var.lgm_email_server_password
    EMAIL_FROM                      = "vanilla.sooft@gmail.com"
    CONTACT_EMAIL                   = "creativestudio.soft@gmail.com"
    NEXT_PUBLIC_CHATBOT_WEBHOOK_URL = "https://ava.logicmatrix.us/chat"
    AZURE_STORAGE_CONNECTION_STRING = var.lgm_azure_storage_connection_string
    AZURE_STORAGE_CONTAINER_NAME    = "lgm"
    # Google OAuth
    # GOOGLE_CLIENT_ID=
    # GOOGLE_CLIENT_SECRET=
  }
}
