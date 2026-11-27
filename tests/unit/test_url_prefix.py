"""Servir Sigma bajo una subruta (``SIGMA_URL_PREFIX``), p. ej. ``http://host/sigma``."""

from __future__ import annotations

from sigma.app_factory import create_app
from sigma.config import Config, _normalize_prefix


def _config(tmp_path, prefix):
    return Config.from_env(
        testing=True,
        instance_dir=tmp_path,
        db_path=tmp_path / "sigma.db",
        notebooks_dir=tmp_path / "notebooks",
        sample_dir=tmp_path / "samples",
        url_prefix=prefix,
    )


def test_normalize_prefix() -> None:
    assert _normalize_prefix("") == ""
    assert _normalize_prefix("/") == ""
    assert _normalize_prefix("sigma") == "/sigma"
    assert _normalize_prefix("/sigma/") == "/sigma"
    assert _normalize_prefix("  /sigma  ") == "/sigma"


def test_prefix_serves_app_and_keeps_root_health(tmp_path) -> None:
    app = create_app(_config(tmp_path, "/sigma"))
    app.testing = True
    client = app.test_client()

    # el healthcheck del contenedor sigue disponible en la raíz
    assert client.get("/health").get_json()["status"] == "ok"

    # el prefijo exacto redirige a la barra final
    assert client.get("/sigma").status_code == 301
    assert client.get("/sigma").headers["Location"] == "/sigma/"

    assert client.get("/sigma/health").get_json()["status"] == "ok"

    # una página protegida redirige a la configuración inicial con el prefijo
    response = client.get("/sigma/datos")
    assert response.status_code == 302
    assert response.headers["Location"] == "/sigma/setup"

    app.extensions["sigma"].close()


def test_prefix_injects_base_and_static_urls(tmp_path) -> None:
    app = create_app(_config(tmp_path, "/sigma"))
    app.testing = True
    client = app.test_client()
    body = client.get("/sigma/setup").get_data(as_text=True)
    assert "window.SIGMA_BASE" in body
    assert "/sigma/static" in body
    app.extensions["sigma"].close()
