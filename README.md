# Install Temporal service on a Kubernetes cluster and connect to DataStax Astra.

# Step 1: Prerequisites

## Setup DataStax Astra Database and Astra Token

* [Create an Astra database](https://dtsx.io/3vr0DJ3)
  * When asked for the keyspace name, name it `temporal`. 
  * Once your database is created, navigate back to your database dashboard and click **Add Keyspace**.
  * Name this second keyspace `temporal_visibility`.
  * The status of your database will temporarily go to **Maintenance**, but after a couple seconds you can refresh your screen and the status should go back to **Active**.

* [Create an Astra Token](https://dtsx.io/36VSEu1)
  * Tokens are required to authenticate against Astra with APIs or Drivers. These tokens can be used with multiple databases and can be configured to have specific permissions. In this example, you will create a token with **Admin Role**. 
  * Temporal uses this token to receive credentials and permission to access your database in a similar way to how Cassandra has a “user” and “password”, which we’ll discuss in more detail in Step 4 where you will configure the Persistence Layer in Temporal.
  * When you create your tokens, download the CSV file [**GeneratedToken.csv**] to keep these credentials.

* [Download your secure connect bundle ZIP](https://dtsx.io/3OLdTjl)
  * Download the secure connect bundle [**secure-connect-your_db.zip**] for the database that you created specifically for Temporal. These are unique to each database that you create within your Astra organization. This contains the information for Temporal to initialize a secured TLS connection between it and your Astra DB instance. 

* **Find your Database ID**
  * Lastly, you want to get your Database ID. You can find this in one of two ways:
    - DB identifer is the last ID in the URL when your DB is selected (the "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" part)
      * `https://astra.datastax.com/org/.../database/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
    - Or the "Datacenter ID" without the `-1` at the end (you'll have to copy and remove that trailing `-1`)
    ![image](https://user-images.githubusercontent.com/3710715/161331138-906f4f7f-919e-4f47-a731-a855d54369c5.png)

## Install and Setup required Software

This sequence assumes
* that your system is configured to access a kubernetes cluster (e. g. [AWS EKS](https://aws.amazon.com/eks/), [kind](https://github.com/kubernetes-sigs/kind#:~:text=On%20Linux%3A,choco%20install%20kind), or [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)), and
* that your machine has
  - [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/), 
  - [docker](https://docs.docker.com/get-docker/), and
  - [Helm v3](https://helm.sh)
  installed and able to access your cluster.



# For Mac/Linux Users:

* Clone this repo
```sh
$ git clone https://github.com/rakesh-pavuluri/temporal-astra-helm-charts.git

$ cd temporal-astra-helm-charts/
```

* Move the `GeneratedToken.csv` file you downloaded earlier in to the `scb_token` folder
* Move the `secure-connect-your_db.zip` bundle you downloaded earlier in to the `scb_token` folder and unzip it
* Update the **database-id** field in the `database-id.txt` file under `scb_token` folder

* Now you can update the configurations and migrate the schema to Astra by running `./update_values_linux.sh` or `./update_values_mac.sh`
* **Note:** if you receive a `command not found` error when running the above commands, try `sh update_values_mac.sh` 

**Good! Now you have all the configurations updated with the required values and have successfully migrated the schema to Astra. Now you can skip step-2 and continue from step-3.**


# For Windows Users:

## Migrating Temporal Schema to Astra

* Clone this repo
```sh
$ git clone https://github.com/rakesh-pavuluri/temporal-astra-helm-charts.git

$ cd temporal-astra-helm-charts/schema-migration/
```

* Update `.env` with your Astra token and Database ID
```yaml
# Update these
ASTRA_TOKEN=your-astra-token
ASTRA_DATABASE_ID=your-databaseID
```

* Update the Temporal schema by running `./schema.sh` OR run these commands:
```sh
docker-compose -f docker-compose-schema.yaml run temporal-admin-tools \
  -ep cql-proxy -k temporal setup-schema -v 0.0
docker-compose -f docker-compose-schema.yaml run temporal-admin-tools \
  -ep cql-proxy -k temporal update-schema -d schema/cassandra/temporal/versioned/

docker-compose -f docker-compose-schema.yaml run temporal-admin-tools \
  -ep cql-proxy -k temporal_visibility setup-schema -v 0.0
docker-compose -f docker-compose-schema.yaml run temporal-admin-tools \
  -ep cql-proxy -k temporal_visibility update-schema -d schema/cassandra/visibility/versioned/
```

## Download Helm Chart Dependencies

Download Helm dependencies:

```bash
$ cd temporal-astra-helm-charts

$ helm dependencies update
```

# Step 2: Setup Temporal with Helm Chart

Follow the below steps to setup Temporal and seamlessly connect it to DataStax Astra. 

## Secret Creation

The files in Astra secure connect bundle that was downloaded earlier contains: `ca.crt`, `cert`, and `key`. These are all credentials that will tell Temporal that you’re trying to connect with Astra DB and that you have the access to do so.

With Secrets in K8s, you can store sensitive information and mount it to your deployment.

* Go to your `temporal-astra-helm-charts/templates/` directory.
* Using your preferred text editor (we used VSCode) update `astra-secret.yaml` file in this folder.
* You'll need to update the `ca.crt:`, `cert:`, and `key:` with your details using the following process.
* Navigate to your `Secure Connect Bundle` using your terminal.
* Base64 Encode your `ca.crt`, `cert`, and `key` files then plug them back into the respective fields in your `astra-secret.yaml` file ex. `ca.crt: LS0tLS1CRUdJT...`

  ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
    name: astra-secret
    type: Opaque
    data:
    ca.crt: LS0tLS1CRUdJT...
    cert: LS0tLS1CRUdJT...
    key: LS0tLS1CRUdJT...
  ```
  * Base64 for Mac: `base64 --break 0 <file-name>`
  * Base64 for Windows: `certutil -encode input-file.txt encoded-output.txt`
  * Base64 for Linux: `base64 -w o <path-to-file>`
* Save your `astra-secret.yaml` file.

## Persistence Layer configuration

Now that you’ve gotten this far, we’re going to configure the Persistence Layer of Temporal’s server. The persistence layer, also known as the Data Access layer, is paired with the Temporal Server to allow support for different back-end databases—Cassandra, in this case. 

* Go to the `temporal-astra-helm-charts/values/` directory.
* Edit the `values.cassandra.yaml` file using your preferred editor (ie. VSCode).
* Modify the `hosts` with your `host` from the `config.json` file in the *Secure Connect Bundle*.
* Modify the `password` with your `Astra Token` from the `CSV` file you downloaded earlier.
    * Make sure to update `hosts` and `password` for both `temporal` and `temporal_visibility` sections, as shown below.

      - For `temporal`

        ```yaml
        # Update these
                  hosts: ["your-hostname"]
                  port: 29042
                  keyspace: temporal
                  user: "token"
                  password: "your-astra-token" 
        ```

      - For `temporal_visibility`

        ```yaml
        # Update these
                  hosts: ["your-hostname"]
                  port: 29042
                  keyspace: temporal_visibility
                  user: "token"
                  password: "your-astra-token" 
        ```

* Save your values.cassandra.yaml file.

# Setp 3: Deploy Temporal Server

* Create and deploy your K8s cluster. Once deployed, the K8s cluster should appear up and running in your Docker Desktop. 

```bash
$ kind create cluster
```

* In your `temporal-astra-helm-charts` directory, run this command:

```bash
$ helm install -f values/values.cassandra.yaml --set elasticsearch.enabled=false temporalastra . --timeout 900s
```

* You should see this message if it was successful:

```bash
  NAME: temporalastra
  LAST DEPLOYED: Thu Apr 28 19:00:35 2022  NAMESPACE: default
  STATUS: deployed
  REVISION: 1
  TEST SUITE: None
  NOTES:
  To verify that Temporal has started, run:

    kubectl --namespace=default get pods -l "app.kubernetes.io/instance=temporalastra"
```

* In a different tab, run this command:

  ```bash
  $ kubectl --namespace=default get pods -l "app.kubernetes.io/instance=temporalastra"
  ```

* A successful deployment should look like this: 

  ```bash
  NAME                                                READY   STATUS    RESTARTS   AGE
  temporalastra-admintools-5f69874f98-5c5xh           1/1     Running   0          101s
  temporalastra-frontend-7dfc859754-sppch             1/1     Running   0          101s
  temporalastra-grafana-7755d4b68c-hl8vr              1/1     Running   0          101s
  temporalastra-history-5889dd576f-js9nc              1/1     Running   0          101s
  temporalastra-kube-state-metrics-85c4b567b5-c8v2l   1/1     Running   0          101s
  temporalastra-matching-865bc94679-vdvz4             1/1     Running   0          101s
  temporalastra-web-5c54698c45-mc95l                  1/1     Running   0          101s
  temporalastra-worker-8474bcc9b-m9bhs                1/1     Running   0          101s
  ```
* Allow a couple minutes for all `STATUS` to initialize and switch to `Running`. You can run the `get pods` statement from above to continuously check on the status as it’s initializing.

# Step 4: Test and validate

You can test your connection and play with your Temporal cluster by following [these instructions on GitHub](https://github.com/temporalio/helm-charts#running-temporal-cli-from-the-admin-tools-container). Temporal offers sample apps to test out different workflows in both [Go](https://github.com/temporalio/samples-go/) and [Java](https://github.com/temporalio/samples-java/). You can use both of these to test and validate that your Temporal instance is successfully running. 

* Make sure to use `tctl` to create namespaces dedicated to certain workflows.

```bash
$ kubectl exec -it services/temporalastra-admintools /bin/bash
bash-5.0# tctl --namespace test namespace re
Namespace test successfully registered.
```

## Port Forwarding

Forward your machine’s local port to `Temporal Web UI` to view and access on your local host by running the following commands in a new window:

* Expose your instance’s front end port to your local machine:

```bash
$ kubectl port-forward services/temporalastra-frontend-headless 7233:7233
Forwarding from 127.0.0.1:7233 -> 7233
Forwarding from [::1]:7233 -> 7233
```

* Forward your local machine’s local port to the `Temporal Web UI`

```bash
$ kubectl port-forward services/temporalastra-web 8088:8088
Forwarding from 127.0.0.1:8088 -> 8088
Forwarding from [::1]:8088 -> 8088
```

* When using the sample apps, keep in mind that you want to modify the starter and worker code so that it points to this specific Temporal deployment. For example:

```bash
c, err := client.NewClient(client.Options{HostPort: "127.0.0.1:7233", Namespace: "test"})
```

* Once you have this all running, you should be able to see your workflows reflect on both the Astra UI and the Temporal UI by navigating to http://127.0.0.1:8088 on your browser.

## And you’re all done! 

At this point you should have a better idea of just how powerful a pairing Temporal and Astra DB can be. With this runbook and your [free Astra DB account](https://dtsx.io/3EW1IeQ), you can go ahead and start experimenting with [Temporal samples](https://github.com/temporalio/temporal#run-the-samples). 

