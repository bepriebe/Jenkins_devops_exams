# Exam Kubernetes bootstrap

`exam-rbac.yaml` is a one-time bootstrap manifest for the isolated exam
environments. It creates the prefixed namespaces, a dedicated Jenkins
ServiceAccount in `jenkins-exam-dev`, and namespace-scoped Roles and
RoleBindings for all four namespaces.

The Jenkins identity can manage only application resources inside these four
namespaces. It cannot create or delete namespaces and receives no ClusterRole.
An administrator must apply this file once before Jenkins deployments:

```bash
kubectl apply -f k8s/exam-rbac.yaml
kubectl auth can-i create deployments \
  --as=system:serviceaccount:jenkins-exam-dev:jenkins-exam-deployer \
  -n jenkins-exam-dev
kubectl auth can-i create deployments \
  --as=system:serviceaccount:jenkins-exam-dev:jenkins-exam-deployer \
  -n jenkins-exam-prod
kubectl auth can-i create namespaces \
  --as=system:serviceaccount:jenkins-exam-dev:jenkins-exam-deployer
```

The expected answers are `yes`, `yes`, and `no`. Do not put a generated token
or kubeconfig into Git. Configure the token in Jenkins Credentials instead.
