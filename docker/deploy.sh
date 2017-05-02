#!/bin/bash

function get_object_storage_secret {
	echo $(kubectl --token=${token} get secrets | grep "object-storage" | awk '{print $1}')
}

set -x

build_number=$1
image_name="registry.ng.bluemix.net/hollis_test/bluecompute-web:${build_number}"
#image_name="registry.ng.bluemix.net/hollis_test/bluecompute-web:17"
token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
cluster_name=$(cat /var/run/secrets/bx-auth-secret/CLUSTER_NAME)
ing_host=$(bx cs cluster-get ${cluster_name}|grep 'Ingress host:'|awk '{print $NF}')

# Check if elasticsearch secret exists
#object_storage_secret=$(get_object_storage_secret)

# Delete previous service
# Do rolling update here
bc_web_service=$(kubectl get services | grep bluecompute-web | head -1 | awk '{print $1}')

# Check if service does not exist
if [[ -z "${bc_web_service// }" ]]; then
	# Deploy service
	echo -e "Deploying web application for the first time"

	# Enter secret and image name into yaml
	sed -i.bak s%binding-object-storage%${object_storage_secret}%g web.yaml
	sed -i.bak s%registry.ng.bluemix.net/hollis_test/bluecompute-web:v1%${image_name}%g web.yaml

	# Do the deployment
	kubectl --token=${token} create -f web.yaml
  sed -i "s/{{ing_host}}/$ing_host/g" ing.yaml
  kubectl create -f ing.yaml

else

	# Do rolling update
	echo -e "Doing a rolling update on Web app Deployment"

	kubectl --token=${token} set image deployment/bluecompute-web-depoyment bluecompute-web=${image_name}

	# Watch the rollout update
	kubectl --token=${token} rollout status deployment/bluecompute-web-depoyment
fi


IP_ADDR=$(kubectl --token=${token} get services | grep bluecompute-web | head -1 | awk '{print $3}')
PORT=$(kubectl --token=${token} get services | grep bluecompute-web | head -1 | awk '{print $4}' | sed 's/:.*//')

echo "Access the web app at http://$IP_ADDR:$PORT"

#clean the previous build image
 	if [[ "${IP_ADDR// }" ]]; then
 		echo "delete images from previous build"
		previous_build=$((build_number-1))
  	bx cr image-rm registry.ng.bluemix.net/hollis_test/bluecompute-web:${previous_build}
 	fi

cd ../docker
set +x
