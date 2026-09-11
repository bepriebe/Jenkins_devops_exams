# DATASCIENTEST JENKINS EXAM
# python-microservice-fastapi
Learn to build your own microservice using Python and FastAPI

**English** | [Deutsch](README.de.md)

This English README is the primary version for the course and exam submission.
Keep both language versions aligned when documenting technical changes.

## Local Compose milestone

Prerequisites: Docker with Compose v2 (`up --wait`) and Python 3.
Run all commands from the repository directory:

```bash
docker compose -p jenkins-exam-local config --quiet
docker compose -p jenkins-exam-local up -d --build --wait --wait-timeout 180
python3 tests/smoke.py
docker compose -p jenkins-exam-local exec -T movie_service python -m pip check
docker compose -p jenkins-exam-local exec -T cast_service python -m pip check
docker compose -p jenkins-exam-local ps
git diff --check
```

Nginx routes traffic on port 8080 to the Movie service (direct access: 8001)
and the Cast service (direct access: 8002). Both APIs listen on port 8000
inside their containers and each uses its own PostgreSQL database with a
separate persistent volume. The Movie service validates cast IDs through
the Cast service.
Compose waits for the databases to become healthy before starting the APIs,
and for the API health checks before starting Nginx. The Cast health check
checks OpenAPI availability; the smoke test verifies database access.
Both services pin Uvicorn to `0.33.0` and uvloop to `0.22.1`.
This removes the previous `--loop asyncio` workaround; Uvicorn uses its
automatic event loop selection. Uvicorn 0.11.2 with uvloop 0.22.1 failed
at startup with `RuntimeError: There is no current event loop in thread
'MainThread'`.

Uvicorn has used `asyncio.run()` for event loop management since 0.15.0.
Version 0.33.0 is the last version supporting Python 3.8; support was
removed in 0.34.0. This targeted update retains the other direct
application dependencies.
Source: [Uvicorn Release Notes](https://uvicorn.dev/release-notes/).

- Movie API documentation: http://localhost:8080/api/v1/movies/docs
- Cast API documentation: http://localhost:8080/api/v1/casts/docs

The smoke test checks both databases through Nginx, the cross-service cast
lookup, and rejection of an unknown cast ID. It deletes its test movie.
Each run leaves one uniquely named test cast because the supplied API has
no cast DELETE endpoint.
Use `BASE_URL=http://localhost:8080 python3 tests/smoke.py` to explicitly
set the target URL. Run this only against a designated test environment.

Stop the application without deleting data:

```bash
docker compose -p jenkins-exam-local stop
```

The existing Compose database passwords are local course example values.
Subsequent deployments will require separate credentials supplied at runtime.

Verified locally on 2026-09-11: both images built, Compose configuration
valid, `up --wait` successful, and `python3 tests/smoke.py` completed with
`PASS`. Both APIs and databases reported healthy status.
After updating to Uvicorn 0.33.0 / uvloop 0.22.1, the build, startup without
`--loop asyncio`, smoke test, and `pip check` in both API containers passed
again. Uvicorn's automatic loop configuration creates a `uvloop.Loop` in
both containers.
The next image milestone also passed: both APIs start with the Dockerfile CMD,
have no mounts, and their installed package versions match their lock files.
The smoke test passed again after removing the source mounts and reload commands.
The `jenkins-exam-local` project remains running; test casts 1, 2, and 3 are retained.
This demonstrates local functionality; it is not yet Jenkins/Kubernetes evidence.

## Repository assessment and next exam steps

Initial state: branch `master`, remote `git@github.com:bepriebe/Jenkins_devops_exams.git`.
Two separate Docker build contexts are available. Both Dockerfiles define
an exec-form Uvicorn startup command on port 8000 without `--reload`.
Compose uses that command and the source code included in the image;
it no longer mounts application source directories. Rebuild the images
after changing application code.

The Python base image is pinned by SHA-256 digest. Each service has a
`requirements.lock` containing the previously tested direct and transitive
package versions. The build installs both `requirements.txt` and the lock
file, so conflicting version changes fail instead of silently replacing
a pinned dependency. It also runs `pip check`.
Keep both files aligned when intentionally updating dependencies; validate
the resulting images with the Compose smoke test and compare `pip freeze`
with the lock file before accepting the update.

The build uses the packaging tools from the pinned base image with
`--no-build-isolation`. It no longer installs OS packages from a moving
APT repository. SQLAlchemy's optional C extensions are disabled to avoid
needing GCC; this may reduce result-processing performance, but preserves
the Python implementation. Other native dependencies use available wheels
on the tested Linux amd64 / Python 3.8 platform.
Only the application directory and dependency files are copied into the images.

This fixes base-image and package versions; it does not promise byte-identical
image digests or hash-verified Python downloads. Builds still need access
to DockerHub and PyPI. Python 3.8 and PostgreSQL 12.1 remain from the course
setup, and Nginx still uses `latest`; a wider platform update is a separate step.
References: [Docker image pinning](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions),
[pip repeatable installs](https://pip.pypa.io/en/stable/topics/repeatable-installs/),
[SQLAlchemy C extensions](https://docs.sqlalchemy.org/en/13/intro.html#installing-the-c-extensions).

The Helm chart now renders two API Deployments and two ClusterIP Services,
with environment labels, configurable image repositories/tags, and the real
OpenAPI readiness/liveness paths. It has been linted and rendered for all
four environments with the prefixed namespaces. The values still contain
`CHANGE_ME` image repositories and database credential placeholders. It now
also renders one PostgreSQL StatefulSet, headless Service, PVC, and placeholder
Secret for each API; API Deployments read `DATABASE_URI` from those Secrets.
Runtime Secret replacement, RBAC, and Jenkins stages are still separate.
The old fixed NodePort and `/api/v1/checkapi` probes are removed. Helm 3.17.3
was used for local validation.

`Jenkinsfile` is a Declarative Multibranch Pipeline skeleton. It validates
Compose, builds both images, pushes immutable commit-SHA tags, and deploys
the matching environment for branches `dev`, `qa`, and `staging`. The exact
`master` branch pauses for manual production approval before deploying
`jenkins-exam-prod`.
Configure Jenkins Credentials with IDs `dockerhub-exam` (username/password
or token) and `kubeconfig-exam` (Secret file) before enabling deployment
stages. The DockerHub namespace remains a build parameter and is never stored
in the repository. The pipeline uses `--create-namespace=false`; the RBAC
bootstrap must therefore have been applied by an administrator first.

After the local smoke test, proceed with small milestones:

1. Completed locally: verify application images with pinned build inputs and their own startup command.
2. Completed locally: render two API workloads for `dev`, `qa`, `staging`, and `prod`.
3. Configure the DockerHub destination and Jenkins credentials; use immutable tags.
4. Apply and verify the restricted exam-specific RBAC bootstrap; replace placeholder runtime Secrets.
5. Add Jenkins deployment stages for both APIs and databases,
   automatically to `dev`, `qa`, and `staging`, and with manual approval for `prod`.
6. Demonstrate a complete pipeline run, rollouts, and HTTP checks;
   prepare GitHub/DockerHub links, screenshots, a PDF, and a ZIP archive.

Use lowercase `qa` because Kubernetes namespace names must be DNS-compliant.
The repository now contains the Jenkinsfile skeleton and exam-specific RBAC
bootstrap. Submission artifacts and the first end-to-end Jenkins run are still missing.
