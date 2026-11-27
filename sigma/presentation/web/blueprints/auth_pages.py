"""Public pages: sign in and first-run setup (they use a layout without the application menu)."""

from __future__ import annotations

from flask import Blueprint, redirect, render_template, request, url_for

from sigma.presentation.web.auth import safe_next, session_user
from sigma.presentation.web.blueprints._helpers import shared

bp = Blueprint("auth_pages", __name__)


@bp.get("/login")
def login_page():
    services = shared()
    if services.get_setup_state.setup_required():
        return redirect(url_for("auth_pages.setup_page"))
    target = safe_next(request.args.get("next"))
    if session_user(services) is not None:
        return redirect(request.script_root + target)
    return render_template("pages/login.html", page_title="Iniciar sesión", next_url=target)


@bp.get("/setup")
def setup_page():
    if not shared().get_setup_state.setup_required():
        return redirect(url_for("auth_pages.login_page"))
    return render_template("pages/setup.html", page_title="Configuración inicial")
