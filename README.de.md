# DATASCIENTEST JENKINS EXAM
# python-microservice-fastapi
Learn to build your own microservice using Python and FastAPI

[English](README.md) | **Deutsch**

Die englische Hauptversion ist für Kurs und Prüfungsabgabe vorgesehen.
Technische Änderungen bitte in beiden Sprachversionen nachführen.

## Lokaler Compose-Meilenstein

Voraussetzungen: Docker mit Compose v2 (`up --wait`) und Python 3.
Alle Befehle im Repository-Verzeichnis ausführen:

```bash
docker compose -p jenkins-exam-local config --quiet
docker compose -p jenkins-exam-local up -d --build --wait --wait-timeout 180
python3 tests/smoke.py
docker compose -p jenkins-exam-local exec -T movie_service python -m pip check
docker compose -p jenkins-exam-local exec -T cast_service python -m pip check
docker compose -p jenkins-exam-local ps
git diff --check
```

Nginx leitet Port 8080 an den Movie-Service (direkt: 8001) und den
Cast-Service (direkt: 8002) weiter. Beide APIs verwenden intern Port 8000
und jeweils eine PostgreSQL-Datenbank mit eigenem persistentem Volume.
Der Movie-Service prüft Cast-IDs über den Cast-Service.
Compose wartet vor dem API-Start auf bereite Datenbanken und vor dem
Nginx-Start auf die API-Healthchecks. Der Cast-Healthcheck prüft die
OpenAPI-Erreichbarkeit; den Datenbankzugriff prüft der Smoke-Test.
Beide Services fixieren Uvicorn auf `0.33.0` und uvloop auf `0.22.1`.
Damit entfällt der bisherige Workaround `--loop asyncio`; Uvicorn verwendet
seine automatische Event-Loop-Auswahl. Uvicorn 0.11.2 scheiterte mit uvloop
0.22.1 beim Start an `RuntimeError: There is no current event loop in thread
'MainThread'`.

Uvicorn verwendet seit 0.15.0 `asyncio.run()` zur Event-Loop-Verwaltung.
0.33.0 ist die letzte Version mit Python-3.8-Unterstützung; ab 0.34.0
entfällt diese Unterstützung. Dieses gezielte Update behält die übrigen
direkten Anwendungsabhängigkeiten bei.
Quelle: [Uvicorn Release Notes](https://uvicorn.dev/release-notes/).

- Movie-Dokumentation: http://localhost:8080/api/v1/movies/docs
- Cast-Dokumentation: http://localhost:8080/api/v1/casts/docs

Der Smoke-Test prüft über Nginx beide Datenbanken, die serviceübergreifende
Cast-Zuordnung und die Ablehnung einer unbekannten Cast-ID. Er entfernt
seinen Testfilm. Pro Lauf bleibt ein eindeutig benannter Test-Cast zurück,
weil die bereitgestellte API keinen Cast-DELETE-Endpunkt hat.
Mit `BASE_URL=http://localhost:8080 python3 tests/smoke.py` kann die Zieladresse
explizit gesetzt werden. Nur gegen eine dafür vorgesehene Testumgebung ausführen.

Stoppen ohne Löschen der Daten:

```bash
docker compose -p jenkins-exam-local stop
```

Die vorhandenen Compose-Datenbankpasswörter sind lokale Kurs-Beispielwerte.
Für spätere Deployments werden eigene Credentials zur Laufzeit benötigt.

Lokal verifiziert am 11.09.2026: Beide Images gebaut, Compose-Konfiguration
gültig, `up --wait` erfolgreich und `python3 tests/smoke.py` mit `PASS`
abgeschlossen. Beide APIs und Datenbanken meldeten gesunde Healthchecks.
Nach dem Update auf Uvicorn 0.33.0 / uvloop 0.22.1 erneut erfolgreich
geprüft: Build und Start ohne `--loop asyncio`, Smoke-Test sowie `pip check`
in beiden API-Containern. Uvicorns automatische Loop-Konfiguration erzeugt
in beiden Containern einen `uvloop.Loop`.
Der nächste Image-Meilenstein ist ebenfalls geprüft: Beide APIs starten mit dem
Dockerfile-CMD, haben keine Mounts und ihre installierten Paketversionen stimmen
mit den Lockdateien überein. Der Smoke-Test besteht auch nach dem Entfernen
der Quellcode-Mounts und Reload-Befehle.
Das Projekt `jenkins-exam-local` läuft weiter; Test-Casts 1, 2 und 3 bleiben erhalten.
Dies ist ein lokaler Funktionsnachweis, noch kein Jenkins-/Kubernetes-Nachweis.

## Bestandsaufnahme und nächste Prüfungsschritte

Ausgangsstand: Branch `master`, Remote `git@github.com:bepriebe/Jenkins_devops_exams.git`.
Zwei separate Docker-Build-Kontexte sind vorhanden. Beide Dockerfiles enthalten
einen Uvicorn-Startbefehl in Exec-Form auf Port 8000 ohne `--reload`.
Compose verwendet diesen Befehl und den im Image enthaltenen Quellcode;
die Anwendungsverzeichnisse werden nicht mehr eingebunden. Nach Änderungen
am Anwendungscode müssen die Images neu gebaut werden.

Das Python-Basis-Image ist per SHA-256-Digest fixiert. Pro Service enthält
eine `requirements.lock` die zuvor getesteten direkten und transitiven
Paketversionen. Der Build installiert sowohl `requirements.txt` als auch
die Lockdatei. Widersprüchliche Versionsänderungen führen dadurch zum Fehler,
statt eine fixierte Abhängigkeit still zu ersetzen. Zusätzlich läuft `pip check`.
Bei gezielten Updates beide Dateien gemeinsam pflegen, die resultierenden
Images mit dem Compose-Smoke-Test validieren und `pip freeze` vor Übernahme
mit der Lockdatei vergleichen.

Der Build verwendet mit `--no-build-isolation` die Paketwerkzeuge aus dem
fixierten Basis-Image. Er installiert keine Betriebssystempakete mehr aus
einem veränderlichen APT-Repository. SQLAlchemys optionale C-Erweiterungen
sind deaktiviert, sodass GCC entfällt. Das kann die Verarbeitung von
Ergebnissen verlangsamen; die Python-Implementierung bleibt erhalten.
Andere native Abhängigkeiten verwenden verfügbare Wheels auf der getesteten
Plattform Linux amd64 / Python 3.8.
Nur das Anwendungsverzeichnis und die Abhängigkeitsdateien werden ins Image kopiert.

Damit sind Basis-Image und Paketversionen fixiert. Byte-identische Image-Digests
oder hashgeprüfte Python-Downloads werden nicht zugesichert. Builds benötigen
weiterhin Zugriff auf DockerHub und PyPI. Python 3.8 und PostgreSQL 12.1 bleiben
aus dem Kursstand erhalten; Nginx verwendet weiterhin `latest`. Ein umfassenderes
Plattformupdate bleibt ein eigener Schritt.
Quellen: [Docker Image-Pinning](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions),
[pip Repeatable Installs](https://pip.pypa.io/en/stable/topics/repeatable-installs/),
[SQLAlchemy C-Erweiterungen](https://docs.sqlalchemy.org/en/13/intro.html#installing-the-c-extensions).

Der vorhandene Helm-Chart bildet die Anwendung noch nicht vollständig ab:
ein fremdes Image (`sajjadhz/fastapiapp:latest`), nur ein Deployment,
keine Datenbanken oder Verbindungsvariablen, ein vorausgesetztes `regcred`
und Probes/Test gegen den nicht implementierten Pfad `/api/v1/checkapi`.
Der feste NodePort 30007 kollidiert bei mehreren Releases; Environment-Labels
und Values für vier Umgebungen fehlen. Die optionale HPA-Vorlage verwendet
`autoscaling/v2beta1` und muss für den Zielcluster überprüft/korrigiert werden.
Lokal fehlt Helm; die anfänglichen Aufrufe von `helm lint charts` und
`helm template jenkins-exam charts` konnten deshalb nicht ausgeführt werden.

Nach dem lokalen Smoke-Test folgen kleine Meilensteine:

1. Lokal abgeschlossen: Anwendungsimages mit fixierten Build-Eingaben und eigenem Startbefehl prüfen.
2. DockerHub-Ziel und Jenkins-Credentials anbinden; unveränderliche Tags nutzen.
3. Den vorhandenen Chart für beide APIs, Datenbanken und vier Umgebungen korrigieren,
   linten und rendern; eingeschränktes Exam-RBAC vorbereiten.
4. Declarative Jenkinsfile mit Checkout, Tests, Build, Push und automatischem
   Deployment nach `dev`, `qa` und `staging` ergänzen. `prod` ausschließlich
   für exakt `master` nach manueller Jenkins-Freigabe zulassen.
5. Vollständigen Pipeline-Lauf, Rollouts und HTTP-Prüfungen nachweisen;
   GitHub-/DockerHub-Links, Screenshots, PDF und ZIP vorbereiten.

`qa` wird kleingeschrieben, weil Kubernetes-Namespace-Namen DNS-konform sein müssen.
Jenkinsfile, Exam-RBAC und Abgabeartefakte fehlen im Ausgangsstand.
