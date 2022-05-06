#!/usr/bin/ bash

export working_dir=$(pwd)
export ASTRA_TOKEN=$(cat $working_dir/scb_token/GeneratedToken.csv | awk -F '","' '{print $4}' |  awk -F '"' '{print $1}' | tail -1)
export ASTRA_DATABASE_ID=$(cat $working_dir/scb_token/database-id.txt | awk -F '=' '{print $2}')
export hostname=$(cat $working_dir/scb_token/secure-connect-temporal/config.json | grep "host" | awk -F '"' '{print $4}')
export ca_cert=$(base64 --break 0 $working_dir/scb_token/secure-connect-temporal/ca.crt)
export cert=$(base64 --break 0 $working_dir/scb_token/secure-connect-temporal/cert)
export key=$(base64 --break 0 $working_dir/scb_token/secure-connect-temporal/key)

# Updating .env file to migrate the schema to astra

sed -i -e 's/your-astra-token/'"$ASTRA_TOKEN"'/g' $working_dir/schema-migration/.env
sed -i -e 's/your-databaseID/'"$ASTRA_DATABASE_ID"'/g' $working_dir/schema-migration/.env

# Updating values/values.cassandra.yaml file with hostname and astra token

sed  -i -e 's/your-hostname/'"$hostname"'/g' $working_dir/values/values.cassandra.yaml
sed  -i -e 's/your-astra-token/'"$ASTRA_TOKEN"'/g' $working_dir/values/values.cassandra.yaml

# Updating templates/astra-secret.yaml file with cert info

echo " ca.crt: "$ca_cert >> $working_dir/templates/astra-secret.yaml
echo " cert: "$cert  >> $working_dir/templates/astra-secret.yaml
echo " key: "$key  >> $working_dir/templates/astra-secret.yaml

# Updating helm charts

helm dependencies update

# Migrating the schema to Astra

docker-compose -f schema-migration/docker-compose-schema.yaml run temporal-admin-tools -ep cql-proxy -k temporal setup-schema -v 0.0

docker-compose -f schema-migration/docker-compose-schema.yaml run temporal-admin-tools -ep cql-proxy -k temporal update-schema -d schema/cassandra/temporal/versioned/

docker-compose -f schema-migration/docker-compose-schema.yaml run temporal-admin-tools -ep cql-proxy -k temporal_visibility setup-schema -v 0.0

docker-compose -f schema-migration/docker-compose-schema.yaml run temporal-admin-tools -ep cql-proxy -k temporal_visibility update-schema -d schema/cassandra/visibility/versioned/
