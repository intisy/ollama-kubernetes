#!/bin/bash

kubectl delete service ollama-webui --grace-period=0 --force
kubectl delete deployment ollama-webui --grace-period=0 --force
kubectl delete pvc ollama-pv-claim --grace-period=0 --force
kubectl delete pv ollama-pv --grace-period=0 --force