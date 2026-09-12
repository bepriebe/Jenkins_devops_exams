# Exam Kubernetes bootstrap

This is the one canonical bootstrap procedure. Run every command below from
your **local repository checkout**. The `ssh` commands execute the Kubernetes
work on `k3s-server`; the generated kubeconfig is copied back only for upload
to Jenkins.

The manifest is repeatable. It creates or updates the four prefixed namespaces,
the dedicated `jenkins-exam-deployer` ServiceAccount, and namespace-scoped
permissions. It does not grant permission to create namespaces or other
cluster-wide resources.

## 1. Apply the exam RBAC bootstrap

```bash
ssh k3s-server 'kubectl apply -f -' < k8s/exam-rbac.yaml
```

It is safe to run this command again after a repository update. Do not delete
namespaces to repeat the bootstrap.

## 2. Create the Jenkins kubeconfig on k3s

The script is sent over SSH and runs on `k3s-server`, where it uses the
SSH user's working kubectl configuration to read the k3s CA and the generated
service-account token. It does not require `sudo`. Its first argument is the
output path:

```bash
ssh k3s-server 'bash -s -- /tmp/jenkins-exam-kubeconfig' \
  < k8s/bootstrap/create-jenkins-kubeconfig.sh
```

The script performs the permission checks itself. The expected output is:

```text
deployments dev: yes
deployments prod: yes
namespaces: no
```

There is no separate local `KUBECONFIG=... kubectl auth can-i` command to
remember.

## 3. Copy the file locally and add it to Jenkins

```bash
scp k3s-server:/tmp/jenkins-exam-kubeconfig ./jenkins-exam-kubeconfig
```

In Jenkins, create a **Secret file** credential with the ID
`kubeconfig-exam` and select `./jenkins-exam-kubeconfig`. The Jenkinsfile uses
that credential for Helm and kubectl deployment commands.

After Jenkins has stored the credential, remove both temporary copies:

```bash
rm -f ./jenkins-exam-kubeconfig
ssh k3s-server 'rm -f /tmp/jenkins-exam-kubeconfig'
```

The generated kubeconfig is ignored by Git. Never print or commit it.
