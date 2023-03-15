#!/bin/sh
set -o errexit

# create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
    registry:2

  docker pull quay.io/argoproj/argocd:v2.6.4
  docker tag quay.io/argoproj/argocd:v2.6.4 localhost:5001/argoproj/argocd:v2.6.4
  docker push localhost:5001/argoproj/argocd:v2.6.4

  docker pull ghcr.io/dexidp/dex:v2.35.3
  docker tag ghcr.io/dexidp/dex:v2.35.3 localhost:5001/dexidp/dex:v2.35.3
  docker push localhost:5001/dexidp/dex:v2.35.3

  docker pull public.ecr.aws/docker/library/redis:7.0.7-alpine
  docker tag public.ecr.aws/docker/library/redis:7.0.7-alpine localhost:5001/docker/library/redis:7.0.7-alpine
  docker push localhost:5001/docker/library/redis:7.0.7-alpine

  docker pull quay.io/metallb/controller:v0.13.9
  docker tag quay.io/metallb/controller:v0.13.9 localhost:5001/metallb/controller:v0.13.9
  docker push localhost:5001/metallb/controller:v0.13.9

  docker pull docker.io/istio/proxyv2:1.17.1
  docker tag docker.io/istio/proxyv2:1.17.1 localhost:5001/istio/proxyv2:1.17.1
  docker push localhost:5001/istio/proxyv2:1.17.1

  docker pull gcr.io/istio-testing/pilot:latest
  docker tag gcr.io/istio-testing/pilot:latest localhost:5001/istio-testing/pilot:latest
  docker push localhost:5001/istio-testing/pilot:latest

  docker pull quay.io/metallb/speaker:v0.13.9
  docker tag quay.io/metallb/speaker:v0.13.9 localhost:5001/metallb/speaker:v0.13.9
  docker push localhost:5001/metallb/speaker:v0.13.9

  docker pull docker.io/istio/pilot:1.17.1
  docker tag docker.io/istio/pilot:1.17.1 localhost:5001/istio/pilot:1.17.1
  docker push localhost:5001/istio/pilot:1.17.1

  docker pull gcr.io/heptio-images/ks-guestbook-demo:0.2
  docker tag gcr.io/heptio-images/ks-guestbook-demo:0.2 localhost:5001/heptio-images/ks-guestbook-demo:0.2
  docker push localhost:5001/heptio-images/ks-guestbook-demo:0.2

fi

# create a cluster with the local registry enabled in containerd
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:5000"]
EOF

# connect the registry to the cluster network if not already connected
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

