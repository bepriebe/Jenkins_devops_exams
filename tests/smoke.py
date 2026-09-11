"""Exercise both APIs and databases through Nginx using only the standard library."""

import json
import os
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen


BASE_URL = os.environ.get("BASE_URL", "http://localhost:8080").rstrip("/")


def request(method, path, expected, payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    req = Request(BASE_URL + path, data=body, method=method,
                  headers={"Content-Type": "application/json"})
    try:
        response = urlopen(req, timeout=10)
    except HTTPError as error:
        response = error
    with response:
        data = response.read()
        if response.status != expected:
            raise AssertionError(f"{method} {path}: expected {expected}, got {response.status}: {data!r}")
        return json.loads(data) if data else None


def main():
    for service in ("movies", "casts"):
        request("GET", f"/api/v1/{service}/openapi.json", 200)

    name = "smoke-" + uuid.uuid4().hex[:12]
    cast = request("POST", "/api/v1/casts/", 201,
                   {"name": name, "nationality": "DE"})
    assert request("GET", f"/api/v1/casts/{cast['id']}/", 200)["name"] == name
    payload = {"name": name, "plot": "Compose smoke test", "genres": ["test"],
               "casts_id": [cast["id"]]}
    movie = request("POST", "/api/v1/movies/", 201, payload)
    path = f"/api/v1/movies/{movie['id']}/"
    try:
        stored = request("GET", path, 200)
        assert stored["casts_id"] == [cast["id"]]
        assert stored["name"] == name
        assert any(item["id"] == movie["id"] for item in request("GET", "/api/v1/movies/", 200))
        request("POST", "/api/v1/movies/", 404, dict(payload, casts_id=[-1]))
    finally:
        request("DELETE", path, 200)
    request("GET", path, 404)
    print("PASS: Nginx, both APIs, both databases, cast lookup and missing-cast rejection")
    print(f"Test cast retained: {cast['id']} (the supplied API has no cast delete endpoint)")


if __name__ == "__main__":
    main()
