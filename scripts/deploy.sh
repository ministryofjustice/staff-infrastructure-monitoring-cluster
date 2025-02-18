#! /bin/bash
# A bash script to deploy:
# - AWS Load Balancer Controller Service account
# - AWS Load Balancer Controller
# - External DNS
# - Nginx Ingress Controller

set -e

# Check if the .env file exists
if [ -f .env ]; then
  # If it exists, source the .env file
  source .env
else
  echo ".env file not found. Skipping..."
fi

ORANGE='\033[1;33m'
PURPLE='\033[1;35m'
NC='\033[0m' # No Color

set_variables() {
  printf "\n${ORANGE}############# ${PURPLE}Setting up local variables ${ORANGE}#############${NC}\n"

  # Set local variables from terraform outputs
  terraform_outputs=`terraform output -json`
  application_name=`echo $terraform_outputs | jq -r '.application_name.value'`
  namespace=`echo $terraform_outputs | jq -r '.terraform_workspace.value'`
  region=`echo $terraform_outputs | jq -r '.aws_region.value'`
  aws_assume_role=`echo $terraform_outputs | jq -r '.assume_role.value'`
  terraform_outputs_eks_cluster=`echo $terraform_outputs | jq -r '.eks_cluster.value'`
  eks_cluster_name=`echo $terraform_outputs_eks_cluster | jq -r '.name'`
  eks_cluster_endpoint=`echo $terraform_outputs_eks_cluster | jq -r '.endpoint'`
  grafana_db_endpoint=`echo $terraform_outputs_eks_cluster | jq -r '.db_endpoint'`
  lb_controller_iam_role_arn=`echo $terraform_outputs_eks_cluster | jq -r '.aws_load_balancer_controller_iam_role_arn'`
  external_dns_iam_role_arn=`echo $terraform_outputs_eks_cluster | jq -r '.external_dns_iam_role_arn'`
  efs_csi_driver_iam_role_arn=`echo $terraform_outputs_eks_cluster | jq -r '.aws_efs_csi_driver_iam_role_arn'`
  ebs_csi_driver_iam_role_arn=`echo $terraform_outputs_eks_cluster | jq -r '.aws_ebs_csi_driver_iam_role_arn'`
  efs_file_system_id=`echo $terraform_outputs_eks_cluster | jq -r '.efs_file_system_id'`
  thanos_iam_role_arn=`echo $terraform_outputs_eks_cluster | jq -r '.thanos_iam_role_arn'`
  cloudwatch_iam_role_arn=`echo $terraform_outputs_eks_cluster | jq -r '.cloudwatch_exporter_iam_role_arn'`
  cloudwatch_exporter_development_iam_role_arn=`echo $terraform_outputs_eks_cluster | jq -r '.cloudwatch_exporter_development_iam_role_arn'`
  cloudwatch_exporter_pre_production_iam_role_arn=`echo $terraform_outputs_eks_cluster | jq -r '.cloudwatch_exporter_pre_production_iam_role_arn'`
  thanos_storage_s3_bucket_name=`echo $terraform_outputs_eks_cluster | jq -r '.thanos_storage_s3_bucket_name'`
  kubeconfig_certificate_authority_data=`echo $terraform_outputs | jq -r '.kubeconfig_certificate_authority_data.value'`
  terraform_outputs_certificate=`echo $terraform_outputs | jq -r '.certificate.value'`
  certificate_domain=`echo $terraform_outputs_certificate | jq -r '.certificate_domain'`
  certificate_arn=`echo $terraform_outputs_certificate | jq -r '.certificate_arn'`
  application_domain=`echo $application_name"."$certificate_domain`
  thanos_domain=`echo "thanos-receive."$application_name"."$certificate_domain`
  tags=`echo $terraform_outputs | jq -r '.tags.value'`

  # Set local variables from AWS parameter store
  dhcpApiBasicAuthUsername=`aws ssm get-parameter --name "/codebuild/dhcp/admin/api/basic_auth_username" --with-decryption  --query Parameter.Value --output text`
  dhcpApiBasicAuthPassword=`aws ssm get-parameter --name "/codebuild/dhcp/admin/api/basic_auth_password" --with-decryption  --query Parameter.Value --output text`
  alertmanager_smtp_user=`aws ssm get-parameter --name "/codebuild/pttp-ci-ima-pipeline/production/smtp_user" --with-decryption  --query Parameter.Value --output text`
  alertmanager_smtp_password=`aws ssm get-parameter --name "/codebuild/pttp-ci-ima-pipeline/production/smtp_password" --with-decryption  --query Parameter.Value --output text`
  pagerduty_routing_key=`aws ssm get-parameter --name "/codebuild/pttp-ci-ima-pipeline/production/pagerduty_routing_key" --with-decryption --query Parameter.Value --output text`
  ima_slack_webhook_url=`aws ssm get-parameter --name "/codebuild/pttp-ci-datasource-config-pipeline/development/mojo-ima-platform-alerts_slack_webhook_url" --with-decryption --query Parameter.Value --output text`
  dhcp_dns_slack_webhook_url=`aws ssm get-parameter --name "/codebuild/pttp-ci-datasource-config-pipeline/production/mojo-staff-device-dhcp-dns-alerts_slackwebhook" --with-decryption --query Parameter.Value --output text`
  development_pre_production_dhcp_dns_slack_webhook_url=`aws ssm get-parameter --name "/codebuild/pttp-ci-datasource-config-pipeline/development-pre-production/mojo-staff-device-dhcp-dns-alerts_slackwebhook" --with-decryption --query Parameter.Value --output text`
  certificate_services_slack_webhook_url=`aws ssm get-parameter --name "/codebuild/pttp-ci-ima-pipeline/production/slack_webhook_url/pki-alerts" --with-decryption --query Parameter.Value --output text`
  networks_slack_webhook_url=`aws ssm get-parameter --name "/codebuild/pttp-ci-ima-pipeline/production/slack_webhook_url/mojdt-network-alerts" --with-decryption --query Parameter.Value --output text`
  ost_slack_webhook_url=`aws ssm get-parameter --name "/codebuild/pttp-ci-datasource-config-pipeline/production/ost_slack_webhook_url" --with-decryption --query Parameter.Value --output text`
  network_access_control_production_slack_webhook_url=`aws ssm get-parameter --name "/codebuild/pttp-ci-ima-pipeline/production/slack_webhook_url/network-access-control-network" --with-decryption --query Parameter.Value --output text`
  network_access_control_pre_production_slack_webhook_url=`aws ssm get-parameter --name "/codebuild/pttp-ci-ima-pipeline/pre-production/slack_webhook_url/network-access-control-network" --with-decryption --query Parameter.Value --output text`
  network_access_control_critical_slack_webhook_url=`aws ssm get-parameter --name "/codebuild/pttp-ci-ima-pipeline/production/slack_webhook_url/network-access-control-critical" --with-decryption --query Parameter.Value --output text`
  production_account_id=`aws ssm get-parameter --name "/codebuild/production/account_id" --with-decryption --query Parameter.Value --output text`
  pre_production_account_id=`aws ssm get-parameter --name "/codebuild/pre-production/account_id" --with-decryption --query Parameter.Value --output text`
  development_account_id=`aws ssm get-parameter --name "/codebuild/development/account_id" --with-decryption --query Parameter.Value --output text`
}

base64_encode() {
  echo -n $1 | openssl base64 -A
}

set_kubeconfig() {
  printf "\n${ORANGE}############# ${PURPLE}Setting up kubeconfig ${ORANGE}#############${NC}\n"
  # Set a user entry in kubeconfig
  if [ -z $AWS_PROFILE ]; then
  kubectl config set-credentials $eks_cluster_name --exec-api-version=client.authentication.k8s.io/v1beta1 --exec-command=aws \
    --exec-arg=eks \
    --exec-arg=get-token \
    --exec-arg=--region \
    --exec-arg=$region \
    --exec-arg=--cluster-name \
    --exec-arg=$eks_cluster_name \
    --exec-arg=--role \
    --exec-arg=$aws_assume_role
  else
  kubectl config set-credentials $eks_cluster_name --exec-api-version=client.authentication.k8s.io/v1beta1 --exec-command=aws \
    --exec-arg=eks \
    --exec-arg=get-token \
    --exec-arg=--region \
    --exec-arg=$region \
    --exec-arg=--cluster-name \
    --exec-arg=$eks_cluster_name \
    --exec-arg=--role \
    --exec-arg=$aws_assume_role \
    --exec-env=AWS_PROFILE=$AWS_PROFILE
  fi

  # Create a temporary kubernetes certificate authority cert file
  cat > temp_kubernetes_ca.crt << EOL
$kubeconfig_certificate_authority_data
EOL

  # Set a cluster entry in kubeconfig and use the cert file in it
  kubectl config set-cluster $eks_cluster_name --server=$eks_cluster_endpoint --embed-certs=true --certificate-authority=./temp_kubernetes_ca.crt

  # Remove the temporary cert file
  rm ./temp_kubernetes_ca.crt

  # Set a context entry in kubeconfig
  kubectl config set-context $eks_cluster_name --cluster=$eks_cluster_name --user=$eks_cluster_name --namespace=$namespace

  # Set the current-context in a kubeconfig file
  kubectl config use-context $eks_cluster_name
}

deploy_kube-prometheus-stack() {
  printf "\n${ORANGE}############# ${PURPLE}Deploying Kube prometheus stack ${ORANGE}#############${NC}\n"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --version 69.3.1 \
    -f ./k8s-values/values.kube-prometheus-stack.yaml \
    -n monitoring \
    --create-namespace \
    --set prometheus.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$thanos_iam_role_arn \
    --set alertmanager.config.global.resolve_timeout="5m" \
    --set alertmanager.config.global.smtp_smarthost="email-smtp.eu-west-2.amazonaws.com:587" \
    --set alertmanager.config.global.smtp_from="AlertManager@staff.service.justice.gov.uk" \
    --set alertmanager.config.global.smtp_require_tls="true" \
    --set alertmanager.config.global.smtp_auth_username=$alertmanager_smtp_user \
    --set alertmanager.config.global.smtp_auth_password=$alertmanager_smtp_password \
    --set alertmanager.config.global.pagerduty_url="https://events.pagerduty.com/v2/enqueue"
}

deploy_thanos_stack() {
  printf "\n${ORANGE}############# ${PURPLE}Deploying thanos stack ${ORANGE}#############${NC}\n"
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm upgrade --install thanos bitnami/thanos \
    -f ./k8s-values/values.thanos-stack.yaml \
    -n monitoring \
    --set storegateway.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$thanos_iam_role_arn \
    --set compactor.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$thanos_iam_role_arn \
    --set receive.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$thanos_iam_role_arn \
    --set receive.ingress.hostname=$thanos_domain \
    --set objstoreConfig="type: S3
config:
  bucket: '$thanos_storage_s3_bucket_name'
  endpoint: 's3.eu-west-2.amazonaws.com'
"
  # Create a datasource for Grafana
  kubectl apply -f ./k8s-configmaps/thanos-query-grafana-datasource.yaml -n monitoring

  # Create a dashboard for Grafana with the metrics from the ServiceMonitor\
  kubectl apply -f ./k8s-configmaps/thanos-overview-grafana-dashboard.yaml -n monitoring
}

deploy_shared_resources_helm_chart() {
  printf "\n${ORANGE}############# ${PURPLE}Creating all the shared resources ${ORANGE}#############${NC}\n"
  helm upgrade --install shared-resources ./k8s-helm-charts/shared-resources \
    -n kube-system \
    --set eks_cluster.lb_controller_iam_role_arn=$lb_controller_iam_role_arn \
    --set eks_cluster.efs_csi_driver_iam_role_arn=$efs_csi_driver_iam_role_arn \
    --set eks_cluster.ebs_csi_driver_iam_role_arn=$ebs_csi_driver_iam_role_arn \
    --set eks_cluster.efs_file_system_id=$efs_file_system_id
}

annotate_service_account() {
  printf "\n${ORANGE}############# ${PURPLE}Adding annotation in aws-load-balancer-controller service account ${ORANGE}#############${NC}\n"
  kubectl annotate serviceaccount --overwrite -n kube-system aws-load-balancer-controller \
    eks.amazonaws.com/sts-regional-endpoints=true
}

deploy_aws_lb_controller() {
  printf "\n${ORANGE}############# ${PURPLE}Deploying AWS load balancer controller ${ORANGE}#############${NC}\n"
  kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -f ./k8s-values/values.aws-load-balancer-controller.yaml \
    -n kube-system \
    --set clusterName=$eks_cluster_name
}

deploy_aws_efs_csi_driver() {
  printf "\n${ORANGE}############# ${PURPLE}Deploying AWS EFS CSI Driver ${ORANGE}#############${NC}\n"
  helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
  helm repo update
  helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
    -f ./k8s-values/values.aws-efs-csi-driver.yaml \
    -n kube-system
}

deploy_aws_ebs_csi_driver() {
  printf "\n${ORANGE}############# ${PURPLE}Deploying AWS EBS CSI Driver ${ORANGE}#############${NC}\n"
  helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
  helm repo update
  helm upgrade -i aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
    -f ./k8s-values/values.aws-ebs-csi-driver.yaml \
    -n kube-system
}

deploy_external_dns() {
  printf "\n${ORANGE}############# ${PURPLE}Deploying External-DNS ${ORANGE}#############${NC}\n"
  helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
  helm repo update
  helm upgrade --install external-dns external-dns/external-dns \
    -f ./k8s-values/values.external-dns.yaml \
    -n external-dns \
    --create-namespace \
    --set txtOwnerId=$application_name \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$external_dns_iam_role_arn \
    --set domainFilters[0]=$certificate_domain
  # Create a dashboard for Grafana with the metrics from the ServiceMonitor\
  kubectl apply -f ./k8s-configmaps/external-dns-grafana-dashboard.yaml -n external-dns
}

deploy_ingress_nginx() {
  printf "\n${ORANGE}############# ${PURPLE}Deploying Nginx ingress controller ${ORANGE}#############${NC}\n"
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    -f ./k8s-values/values.ingress-nginx.yaml \
    -n ingress-nginx \
    --create-namespace \
    --set controller.service.annotations."external-dns\.alpha\.kubernetes\.io/hostname"=$application_domain \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-ssl-cert"=$certificate_arn \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-additional-resource-tags"=$tags
  # wait 10 seconds for ingress controller to be in ready state.
  sleep 10
}

deploy_grafana() {
  printf "\n${ORANGE}############# ${PURPLE}Deploying Grafana ${ORANGE}#############${NC}\n"
  helm repo add grafana https://grafana.github.io/helm-charts
  helm repo update
  helm upgrade --install grafana grafana/grafana \
    --version 8.8.2 \
    -f ./k8s-values/values.grafana.yaml \
    -n grafana \
    --create-namespace \
    --set ingress.hosts[0]=$application_domain \
    --set env.GF_AUTH_AZUREAD_CLIENT_ID=$AZUREAD_CLIENT_ID \
    --set env.GF_AUTH_AZUREAD_CLIENT_SECRET=$AZUREAD_CLIENT_SECRET \
    --set env.GF_AUTH_AZUREAD_AUTH_URL=$AZUREAD_AUTH_URL \
    --set env.GF_AUTH_AZUREAD_TOKEN_URL=$AZUREAD_TOKEN_URL \
    --set env.GF_SERVER_ROOT_URL=$SERVER_ROOT_URL \
    --set env.GF_DATABASE_TYPE="postgres" \
    --set env.GF_DATABASE_HOST=$grafana_db_endpoint \
    --set env.GF_DATABASE_USER=$DB_USERNAME \
    --set env.GF_DATABASE_PASSWORD=$DB_PASSWORD \
    --set env.GF_DATABASE_NAME=$DB_NAME
  kubectl apply -f ./k8s-persistent-volume-claims/grafana-persistent-volume-claim.yaml -n grafana
}

deploy_cns_team_monitoring() {
  printf "\n${ORANGE}############# ${PURPLE}Deploying CNS Team monitoring helm chart ${ORANGE}#############${NC}\n"
   # Check environment and set values file path or reconfigure values
    if [ "$namespace" == "production" ]; then
      helm upgrade --install cns-team-monitoring ./k8s-helm-charts/cns-team-monitoring \
        -n monitoring \
        --set dhcpApiBasicAuthUsername="$dhcpApiBasicAuthUsername" \
        --set dhcpApiBasicAuthPassword="$dhcpApiBasicAuthPassword" \
        --set environment="$namespace" \
        --set production_account_id="$production_account_id" \
        --set pre_production_account_id="$pre_production_account_id" \
        --set development_account_id="$development_account_id" \
        --set cloudwatch_iam_role="$cloudwatch_iam_role_arn" \
        --set cloudwatchExporterDevelopmentArn="$cloudwatch_exporter_development_iam_role_arn" \
        --set cloudwatchExporterPreProductionArn="$cloudwatch_exporter_pre_production_iam_role_arn" \
        --set alertmanager.alert_rules.pagerduty_routing_key=$(base64_encode "$pagerduty_routing_key") \
        --set alertmanager.alert_rules.ima_slack_webhook_url=$(base64_encode "$ima_slack_webhook_url") \
        --set alertmanager.alert_rules.dhcp_dns_slack_webhook_url=$(base64_encode "$dhcp_dns_slack_webhook_url") \
        --set alertmanager.alert_rules.development_pre_production_dhcp_dns_slack_webhook_url=$(base64_encode "$development_pre_production_dhcp_dns_slack_webhook_url") \
        --set alertmanager.alert_rules.certificate_services_slack_webhook_url=$(base64_encode "$certificate_services_slack_webhook_url") \
        --set alertmanager.alert_rules.networks_slack_webhook_url=$(base64_encode "$networks_slack_webhook_url") \
        --set alertmanager.alert_rules.ost_slack_webhook_url=$(base64_encode "$ost_slack_webhook_url") \
        --set alertmanager.alert_rules.network_access_control_production_slack_webhook_url=$(base64_encode "$network_access_control_production_slack_webhook_url") \
        --set alertmanager.alert_rules.network_access_control_pre_production_slack_webhook_url=$(base64_encode "$network_access_control_pre_production_slack_webhook_url") \
        --set alertmanager.alert_rules.network_access_control_critical_slack_webhook_url=$(base64_encode "$network_access_control_critical_slack_webhook_url")
    else
      values_file="./k8s-helm-charts/cns-team-monitoring-non-production/values-$namespace.yaml"
      helm upgrade --install cns-team-monitoring ./k8s-helm-charts/cns-team-monitoring \
        -n monitoring \
        --set dhcpApiBasicAuthUsername="$dhcpApiBasicAuthUsername" \
        --set dhcpApiBasicAuthPassword="$dhcpApiBasicAuthPassword" \
        --set environment="$namespace" \
        --set production_account_id="$production_account_id" \
        --set pre_production_account_id="$pre_production_account_id" \
        --set development_account_id="$development_account_id" \
        --set cloudwatch_iam_role="$cloudwatch_iam_role_arn" \
        --set cloudwatchExporterDevelopmentArn="$cloudwatch_exporter_development_iam_role_arn" \
        --set cloudwatchExporterPreProductionArn="$cloudwatch_exporter_pre_production_iam_role_arn" \
        --values "$values_file"
    fi
  }

main() {
  set_variables
  set_kubeconfig
  deploy_kube-prometheus-stack
  deploy_thanos_stack
  deploy_shared_resources_helm_chart
  annotate_service_account
  deploy_aws_lb_controller
  deploy_aws_efs_csi_driver
  deploy_aws_ebs_csi_driver
  deploy_external_dns
  deploy_ingress_nginx
  deploy_grafana
  deploy_cns_team_monitoring
}

if `terraform output enabled`; then
  printf "\n${ORANGE}############# ${PURPLE}Preparing the EKS Cluster for deployments in `terraform output -raw terraform_workspace` ${ORANGE}#############${NC}\n"
  main
else
  printf "\n${ORANGE}############# ${PURPLE}Nothing to deploy as environment: `terraform output -raw terraform_workspace` is not enabled ${ORANGE}#############${NC}\n"
fi
