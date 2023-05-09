#!/bin/bash
set -e

# File runs the whoami example of traefik
# https://doc.traefik.io/traefik/getting-started/quick-start-with-kubernetes/
# Useful to see if the configuration of the network is fine

# Install script need local bin in the path
export PATH=$PATH:/usr/local/bin

cat > /tmp/03-whoami.yml <<EOF1
kind: Deployment
apiVersion: apps/v1
metadata:
  name: whoami
  labels:
    app: whoami

spec:
  replicas: 1
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
        - name: whoami
          image: traefik/whoami
          ports:
            - name: web
              containerPort: 80
EOF1

cat > /tmp/03-whoami-services.yml <<EOF2
apiVersion: v1
kind: Service
metadata:
  name: whoami

spec:
  ports:
    - name: web
      port: 80
      targetPort: web

  selector:
    app: whoami
EOF2

cat > /tmp/04-whoami-ingress.yml <<EOF3
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami-ingress
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: whoami
            port:
              name: web
EOF3

kubectl apply -f /tmp/03-whoami.yml \
              -f /tmp/03-whoami-services.yml \
              -f /tmp/04-whoami-ingress.yml
