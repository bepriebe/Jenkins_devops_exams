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
The `jenkins-exam-local` project remains running; test casts 1 and 2 are retained.
This demonstrates local functionality; it is not yet Jenkins/Kubernetes evidence.

## Repository assessment and next exam steps

Initial state: branch `master`, remote `git@github.com:bepriebe/Jenkins_devops_exams.git`.
Two separate Docker build contexts are available. The Dockerfiles do not
yet define a startup command; Compose supplies it, including development
mode (`--reload` and source code bind mounts). Python 3.8, PostgreSQL 12.1,
and the other direct Python dependencies come from the original course
materials. Base images and transitive Python dependencies are not yet
fully pinned; Nginx uses `latest`.

The existing Helm chart does not yet represent the complete application:
it references a third-party image (`sajjadhz/fastapiapp:latest`), defines
only one deployment, provides no databases or connection environment
variables, assumes an existing `regcred`, and targets the unimplemented
`/api/v1/checkapi` path in its probes and test.
The fixed NodePort 30007 conflicts across multiple releases; environment
labels and values for four environments are missing. The optional HPA
template uses `autoscaling/v2beta1` and needs review/correction for the
target cluster.
Helm is not installed locally, so the initial `helm lint charts` and
`helm template jenkins-exam charts` commands could not be executed.

After the local smoke test, proceed with small milestones:

1. Prepare reproducible application images that can start independently.
2. Configure the DockerHub destination and Jenkins credentials; use immutable tags.
3. Correct, lint, and render the existing chart for both APIs, databases,
   and four environments; prepare restricted exam-specific RBAC.
4. Add a Declarative Jenkinsfile with checkout, tests, build, push, and
   automatic deployment to `dev`, `qa`, and `staging`. Allow `prod` only
   from the exact branch `master`, after manual approval in Jenkins.
5. Demonstrate a complete pipeline run, rollouts, and HTTP checks;
   prepare GitHub/DockerHub links, screenshots, a PDF, and a ZIP archive.

Use lowercase `qa` because Kubernetes namespace names must be DNS-compliant.
The initial repository has no Jenkinsfile, exam-specific RBAC, or submission artifacts.
