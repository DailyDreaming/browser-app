#!/usr/bin/with-contenv bash

[[ -z "${GOOGLE_PROJECT}" ]] || echo "export GOOGLE_PROJECT=${GOOGLE_PROJECT}" >> /etc/apache2/envvars
[[ -z "${WORKSPACE_NAME}" ]] || echo "export WORKSPACE_NAME=${WORKSPACE_NAME}" >> /etc/apache2/envvars
[[ -z "${WORKSPACE_NAMESPACE}" ]] || echo "export WORKSPACE_NAMESPACE=${WORKSPACE_NAMESPACE}" >> /etc/apache2/envvars
echo "export WHOAMI=$(whoami)" >> /etc/apache2/envvars
echo "export STARTING_ENV='$(env)'" >> /etc/apache2/envvars

mkdir -p ~/.config/gcloud
mkdir -p /var/www/.config/gcloud
#echo $CREDS >> ~/.config/gcloud/application_default_credentials.json
#echo $CREDS >> /var/www/.config/gcloud/application_default_credentials.json
#echo $SERVICE_ACCOUNT >> ~/.config/sa_credentials.json
#echo $SERVICE_ACCOUNT >> /var/www/.config/sa_credentials.json

service apache2 start
