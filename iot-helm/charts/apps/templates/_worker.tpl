{{- define "worker" -}}
{{- $name := .name }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $name }}
  labels:
    app: {{ $name }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ $name }}
  template:
    metadata:
      labels:
        app: {{ $name }}
    spec:
      initContainers:
        - name: wait-for-db
          image: busybox:1.36
          command: ['sh', '-c', 'until nc -z timescaledb 5432; do echo waiting for db; sleep 2; done']
      containers:
        - name: {{ $name }}
          image: {{ include "iot.image" (dict "name" $name "values" .root.Values) | quote }}
          imagePullPolicy: {{ if eq .root.Values.imageMode "kind" }}Never{{ else if eq .root.Values.imageMode "release" }}IfNotPresent{{ else }}Always{{ end }}
          ports:
            - name: metrics
              containerPort: 8000
          env:
            - name: SERVICE_NAME
              value: {{ $name }}
            - name: DB_HOST
              value: timescaledb
            - name: DB_PORT
              value: "5432"
            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: iot-central-secret
                  key: timescaledb_db
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: iot-central-secret
                  key: timescaledb_user
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: iot-central-secret
                  key: timescaledb_password
            - name: KAFKA_BOOTSTRAP
              value: kafka:9092
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 300m
              memory: 256Mi
          securityContext:
            runAsNonRoot: true
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          readinessProbe:
            httpGet:
              path: /metrics
              port: metrics
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /metrics
              port: metrics
            initialDelaySeconds: 15
            periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}
  labels:
    app: {{ $name }}
spec:
  selector:
    app: {{ $name }}
  ports:
    - name: metrics
      port: 8000
      targetPort: metrics
{{- if eq .root.Values.imageMode "lab" }}
---
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: {{ $name }}
  labels:
    app: {{ $name }}
---
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: {{ $name }}
  labels:
    app: {{ $name }}
spec:
  successfulBuildsHistoryLimit: 1
  failedBuildsHistoryLimit: 1
  output:
    to:
      kind: ImageStreamTag
      name: {{ $name }}:latest
  source:
    type: Binary
    binary: {}
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: {{ printf "%s/Dockerfile" $name | quote }}
{{- end }}
{{- end }}
