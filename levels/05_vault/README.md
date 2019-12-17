# Vault Level 05
create enviroment variable to include your ssh key. You will need this to connect to the server in this step
```sh
TF_VAR_ssh_key_name=<YOUR KEY-PAIR NAME IN AWS TO CONNECT TO THE SERVER>
```
change directory to 05_vault directory and execute the following commands
```sh
terraform apply
export VAULT_ADDR="http://$(terraform output one_vault_addr):8200"
export VAULT_SKIP_VERIFY=1
```
# Let's initialize the vault server
```sh
vault operator init -tls-skip-verify -key-shares=1 -key-threshold=1
```

Keep the Unseal key and Initial Root Token they will look like that:
```sh
Unseal Key 1: 3DsIrKJn6If9/kasdfasdfvJsG5fIRLt2urg=
Initial Root Token: s.YvasdasdasdlqiAdFppJXq3T88
```

Check the status of the vault server
```sh
vault status
```
Run unseal provide Unseal Key when asked
```sh
vault operator unseal
```
Check the status of the vault server again and notice what changed
```sh
vault status
```
Login to vault server
```sh
vault login 
```

# Now let's create dynamic secret for our RDS
```sh
vault secrets  enable  database
```
This command creates a reference to our RDS that will be called my-mysql-database
```sh
export RDS_ENDPOINT="$(terraform output rds_endpoint)"
vault write database/config/my-mysql-database \
    plugin_name=mysql-rds-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(${RDS_ENDPOINT})/" \
    allowed_roles="my-role" \
    username="root" \
    password="devopsdays4life"
```

Now we create a role that will create on demand mysql users with  SELECT ON *.* and default time to live of 1 hour
```sh
vault write database/roles/my-role \
    db_name=my-mysql-database \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';" \
    default_ttl="1h" \
    max_ttl="24h"    
```
Try creating dynamic credentials yourself 
```sh
vault read database/creds/my-role    
```

# Creating a policy and AWS auth 
Review file policy.hcl

and let's create a policy called old-monolyth-policy
```sh
vault policy write old-monolyth-policy policy.hcl
```
Adding AWS auth - this will allow our EC2 instance identify themselves to vault to get proper policy
```sh
vault auth enable aws
vault write auth/aws/config/client secret_key=${AWS_SECRET_ACCESS_KEY} access_key=${AWS_ACCESS_KEY_ID}
```
Check the ARN of the IAM role of the ooc-client 

And run the following command changing to the proper value
```sh
vault write auth/aws/role/dev-role-iam auth_type=iam bound_iam_principal_arn=<ARN OF IAM ROLE> policies=old-monolyth-policy max_ttl=500h
```

Browse to public IP of ooc-client

# Vault Agent Setup
Open new terminal window

ssh to the ooc-client ec2-instance that was created

copy local index.ctmpl to the ooc-client to /etc/vault.d/index.ctmpl (see file content below)
```htlm
Please decompose me!
</br>
</br>
I'm spilling over the credentials
</br>
{{ with secret "database/creds/my-role" }}
USER {{ .Data.username }} </br>
PASSWORD{{ .Data.password }} </br>
{{ end }}
```

Run the following command to update the placeholder with real vault address on your laptop (in 05_vault directory)
```sh
sed -i.bu "s+REPLACE_WITH_YOUR_VAULT_IP+$VAULT_ADDR+g"  client.hcl
```

copy  local client.hcl to the ooc-client to /etc/vault.d/client.hcl

execute the following command on ooc-client
```sh
vault agent -config=/etc/vault.d/client.hcl
```
Browse to public IP of ooc-client
