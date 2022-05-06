#!/usr/bin/ bash

export working_dir=$(pwd)
export ASTRA_TOKEN=$(cat $working_dir/scb_token/GeneratedToken.csv | awk -F '","' '{print $4}' |  awk -F '"' '{print $1}' | tail -1)
export ASTRA_DATABASE_ID=$(cat $working_dir/scb_token/database-id.txt | awk -F '=' '{print $2}')
export hostname=$(cat $working_dir/scb_token/secure-connect-temporal/config.json | grep "host" | awk -F '"' '{print $4}')
export ca_cert=$(base64 -w o $working_dir/scb_token/secure-connect-temporal/ca.crt)
export cert=$(base64 -w o $working_dir/scb_token/secure-connect-temporal/cert)
export key=$(base64 -w o $working_dir/scb_token/secure-connect-temporal/key)

# Updating .env file to migrate the schema to astra

sed -i -e 's/your-astra-token/'"$ASTRA_TOKEN"'/g' $working_dir/schema-migration/.env
sed -i -e 's/your-databaseID/'"$ASTRA_DATABASE_ID"'/g' $working_dir/schema-migration/.env

# Updating values/values.cassandra.yaml file with hostname and astra token

sed  -i -e 's/your-hostname/'"$hostname"'/g' $working_dir/values/values.cassandra.yaml
sed  -i -e 's/your-astra-token/'"$ASTRA_TOKEN"'/g' $working_dir/values/values.cassandra.yaml

# Updating templates/astra-secret.yaml file with cert info

sed -i -e 's/'"ca.crt: LS0tLS1CRUdJT..."'/'"ca.crt: $ca_cert"'/g' $working_dir/templates/astra-secret.yaml
sed -i -e 's/'"cert: LS0tLS1CRUdJT..."'/'"cert: $cert"'/g' $working_dir/templates/astra-secret.yaml
sed -i -e 's/'"key: LS0tLS1CRUdJT..."'/'"key: $key"'/g' $working_dir/templates/astra-secret.yaml

# Updating helm charts

helm dependencies update

# Migrating the schema to Astra

docker-compose -f $working_dir/schema-migration/docker-compose-schema.yaml run temporal-admin-tools -ep cql-proxy -k temporal setup-schema -v 0.0

docker-compose -f $working_dir/schema-migration/docker-compose-schema.yaml run temporal-admin-tools -ep cql-proxy -k temporal update-schema -d schema/cassandra/temporal/versioned/

docker-compose -f $working_dir/schema-migration/docker-compose-schema.yaml run temporal-admin-tools -ep cql-proxy -k temporal_visibility setup-schema -v 0.0

docker-compose -f $working_dir/schema-migration/docker-compose-schema.yaml run temporal-admin-tools -ep cql-proxy -k temporal_visibility update-schema -d schema/cassandra/visibility/versioned/
