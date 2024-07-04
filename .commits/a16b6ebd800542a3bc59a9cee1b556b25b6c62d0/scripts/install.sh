#!/bin/bash

sha=$1
using_kubernetes=true

wait_until_ready() {
  url=$1
  substring1="The requested URL returned error"
  substring2="Could not resolve host: raw.githubusercontent.com"
  echo "Executing: $url"
  output=$(curl -fsSL $url 2>&1)
  if [[ $output =~ $substring1 || $output =~ $substring2 ]]; then
    sleep 1
    wait_until_ready
  fi
}
wait_until_ready https://raw.githubusercontent.com/WildePizza/ollama-kubernetes/HEAD/.commits/$sha/scripts/deinstall.sh
curl -fsSL https://raw.githubusercontent.com/WildePizza/ollama-kubernetes/HEAD/.commits/$sha/scripts/deinstall.sh | bash -s
sudo mkdir ~/ollama
cd ~/ollama
if [ "$using_kubernetes" = true ]; then
  kubectl apply -f - <<OEF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ollama-pv
spec:
  capacity:
    storage: 1500Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  claimRef:
    namespace: default
    name: ollama-pv-claim
  storageClassName: local-storage
  local:
    path: "$(pwd)"
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - blizzity2
OEF
  kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-pv-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1500Gi
EOF
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama-webui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama-webui
  template:
    metadata:
      labels:
        app: ollama-webui
    spec:
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 15
        periodSeconds: 20
        failureThreshold: 3
      restartPolicy: Always
      containers:
      - name: ollama-webui
        image: ghcr.io/open-webui/open-webui:git-740b6f5-cuda
        imagePullPolicy: Always
        ports:
        - containerPort: 722
          name: http
          protocol: TCP
        volumeMounts:
        - name: ollama-pv
          mountPath: /app/backend/data
      volumes:
      - name: ollama-pv
        persistentVolumeClaim:
          claimName: ollama-pv-claim
EOF
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ollama-webui
spec:
  type: LoadBalancer
  selector:
    app: ollama-webui
  ports:
  - protocol: TCP
    port: 722
    targetPort: 8080
EOF
else
  sudo docker run -d -p 722:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
fi
