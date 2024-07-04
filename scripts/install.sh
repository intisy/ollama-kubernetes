#!/bin/bash

using_kubernetes=true


curl -fsSL https://raw.githubusercontent.com/WildePizza/ollama-kubernetes/HEAD/run.sh | bash -s deinstall
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
      containers:
      - name: ollama-webui
        image: ghcr.io/open-webui/open-webui:git-740b6f5-cuda
        imagePullPolicy: Always
        ports:
        - containerPort: 722
          name: http
          protocol: TCP
        publish:
        - hostPort: 722
          protocol: TCP
          port: 8080
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
