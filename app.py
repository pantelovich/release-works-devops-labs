"""A small HTTP service for release and recovery practice."""

import os

from flask import Flask


def create_app() -> Flask:
    """Create the service with its lab release and health configuration."""
    version = os.environ.get("RELEASE_VERSION", "dev")
    health = os.environ.get("RELEASE_HEALTH", "healthy")
    if health not in {"healthy", "unhealthy"}:
        raise ValueError("RELEASE_HEALTH must be healthy or unhealthy")

    app = Flask(__name__)

    @app.get("/healthz")
    def health_check() -> tuple[dict[str, str], int]:
        """Report whether this release is ready for traffic."""
        return {"status": health}, 200 if health == "healthy" else 503

    @app.get("/version")
    def release_version() -> dict[str, str]:
        """Report the version serving the request."""
        return {"version": version}

    return app


app = create_app()
