"""Check the service contracts exercised by the release labs."""

import os
import unittest
from unittest.mock import patch

from app import create_app


class ReleaseServiceTests(unittest.TestCase):
    """Verify the ready, degraded and invalid configurations."""

    def test_healthy_release_reports_version(self) -> None:
        with patch.dict(
            os.environ, {"RELEASE_VERSION": "v1", "RELEASE_HEALTH": "healthy"}
        ):
            client = create_app().test_client()
        self.assertEqual(client.get("/healthz").status_code, 200)
        self.assertEqual(client.get("/version").json, {"version": "v1"})

    def test_failed_candidate_reports_its_own_version(self) -> None:
        with patch.dict(
            os.environ, {"RELEASE_VERSION": "v2", "RELEASE_HEALTH": "unhealthy"}
        ):
            client = create_app().test_client()
        response = client.get("/healthz")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json, {"status": "unhealthy"})
        self.assertEqual(client.get("/version").json, {"version": "v2"})

    def test_invalid_health_configuration_is_rejected(self) -> None:
        with patch.dict(os.environ, {"RELEASE_HEALTH": "typo"}):
            with self.assertRaises(ValueError):
                create_app()
