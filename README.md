headlamp:
k apply -f headlamp-deployment.yml -f headlamp-ingress.yml
https://headlamp.dev/docs/latest/installation/ :
kubectl -n kube-system create serviceaccount headlamp-admin
kubectl create clusterrolebinding headlamp-admin --serviceaccount=kube-system:headlamp-admin --clusterrole=cluster-admin
kubectl create token headlamp-admin -n kube-system

traefik:
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.7.0/standard-install.yaml
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  -f traefik-values.yml
k apply -f traefik-gateway.yml

mysql:
k apply -f mysql/mysql-secret.yml -f mysql/mysql-svc.yml -f mysql/mysql-sts.yml

se co au registry: 
kubectl create secret docker-registry regcred \
  --docker-server=aaa.com \
  --docker-username=xxxxxx \
  --docker-password=xxxxxx


app:
k apply -f sampleapp-httproute.yml -f sampleapp-deployment.yml