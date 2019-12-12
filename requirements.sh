#!/bin/bash
#
# This script is checking that all the requiered binaries are available and application versions are suitable
# It also inits terraform and downloads the needed plugins

MAGIC=$1

starprint(){
  local INPUT=$*
  local LENGTH=$(echo "$INPUT" | awk '{print length+4}')
  line() { for i in $(eval echo "{1..$LENGTH}"); do echo -n '*'; done; echo; }
  line
  echo -n "* "; echo -n $INPUT;echo -n " *";echo
  line
}

app_check(){
	local app_name=$1
	local desired_app_version=$2
	command -v $app_name >/dev/null
	if [[ $? -ne 0 ]]; then
    	echo "$app_name not found"
    	echo "Please download $desired_app_version"
    	return 1
  	else
  		local app_version="$($app_name version | head -n 1)" # Consul is talking too much
  		if [[ "$app_version" =~ "$desired_app_version" ]]; then
	  		echo "Found $app_version - OK"
  		else
  			echo "Found $app_version, but $desired_app_version is required, please update"
  			return 1
	  	fi
  	fi
}

app_check packer "Packer v1.4.5"
app_check consul "Consul v1.6.1"
app_check vault "Vault v1.3.0"
app_check terraform "Terraform v0.12.17" && \

for folder in $(ls -1 levels); do
	if [[ -f "levels/$folder/main.tf" ]]; then
		cd "levels/$folder"
		starprint "Initialising terraform plugins in levels/$folder"
		terraform init
    if [[ -n $MAGIC ]]; then
		  terraform $MAGIC -auto-approve
    fi
		cd -
	fi
done
