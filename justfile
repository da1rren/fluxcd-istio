github_user := env_var('GITHUB_USER')

cluster: _cluster _flux _lb
	
	
cleanup:
	kind delete clusters --all

rebuild: cleanup cluster

_cluster:
	./kind.sh
	kubectl create namespace argocd

_flux:
	flux bootstrap github \
	--owner={{github_user}} \
	--repository=fluxcd-istio \
	--branch=main \
	--path=./environments/local \
	--read-write-key
	--personal

_lb:					
	helm install metallb -n metallb-system \
	--create-namespace \
	-f environments/local/metallb/values.yaml metallb/metallb 

	kubectl wait deployment -n metallb-system --for condition=Available=True --timeout=240s --all

	kubectl apply -f '{{justfile_directory()}}/charts/metal-lb/ip-pool.yaml'
