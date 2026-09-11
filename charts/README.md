### Exam chart

The chart renders the two API workloads (`movie` and `cast`) for one
environment/release. Set `environment` to `dev`, `qa`, `staging`, or `prod`
and deploy into the matching prefixed namespace (`jenkins-exam-<environment>`).
Both services use `ClusterIP`; no fixed NodePort is allocated. Images and
immutable tags are supplied through `services.movie` and `services.cast`.

The chart also renders one PostgreSQL StatefulSet, headless Service, PVC, and
placeholder Secret for each API. API Deployments read their `DATABASE_URI`
from the matching Secret. Runtime Secret replacement, RBAC, and Jenkins
deployment stages remain separate follow-up steps.

Example validation:

```bash
helm lint charts
helm template exam-dev charts --namespace jenkins-exam-dev --set environment=dev
```

### How to create helm chart from manifests
To create helm chart run following command and edit values, chart files and files in templates directory based on your k8s manifests:

```
$ helm create fastapiapp
```

Now move to the fastapiapp directory and run tree command you should see:

```
$ tree
.
├── charts
├── Chart.yaml
├── README.md
├── templates
│   ├── deployment.yaml
│   ├── _helpers.tpl
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt
│   ├── serviceaccount.yaml
│   ├── service.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml
```

Now you can edit Chart.yaml and modify appVersion and chart version. You can edit values.yaml and provide image registry, name and tag and whatever you want.
