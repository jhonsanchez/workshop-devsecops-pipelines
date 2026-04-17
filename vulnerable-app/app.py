import sqlite3
import os
from flask import Flask, jsonify

from src.auth.login import login, register
from src.api.users import get_users, get_user, admin_panel
from src.views.search import search
from src.utils.crypto import hash_password

app = Flask(__name__)

# VULNERABLE: Debug mode enabled in production (CWE-489)
app.config["DEBUG"] = True
# VULNERABLE: Weak secret key (CWE-330)
app.config["SECRET_KEY"] = "super-secret-key-123"


def init_db():
    """Initialize the database with sample data."""
    db = sqlite3.connect("/tmp/app.db")
    db.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            email TEXT,
            role TEXT DEFAULT 'user'
        )
    """)
    # Seed with sample users
    existing = db.execute("SELECT COUNT(*) FROM users").fetchone()[0]
    if existing == 0:
        users = [
            ("admin", hash_password("admin123"), "admin@entelgy.com", "admin"),
            ("developer", hash_password("dev2024"), "dev@entelgy.com", "user"),
            ("analyst", hash_password("security1"), "analyst@entelgy.com", "user"),
        ]
        db.executemany(
            "INSERT INTO users (username, password, email, role) VALUES (?, ?, ?, ?)",
            users,
        )
        db.commit()
    db.close()


# Routes
app.add_url_rule("/login", view_func=login, methods=["POST"])
app.add_url_rule("/register", view_func=register, methods=["POST"])
app.add_url_rule("/api/users", view_func=get_users, methods=["GET"])
app.add_url_rule("/api/users/<int:user_id>", view_func=get_user, methods=["GET"])
app.add_url_rule("/admin", view_func=admin_panel, methods=["GET"])
app.add_url_rule("/search", view_func=search, methods=["GET"])


@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/")
def index():
    return jsonify({
        "app": "DevSecOps Vulnerable App",
        "version": "1.0.0",
        "endpoints": ["/login", "/register", "/api/users", "/search", "/admin", "/health"],
    })


with app.app_context():
    init_db()

if __name__ == "__main__":
    # VULNERABLE: Binding to 0.0.0.0 with debug mode
    app.run(host="0.0.0.0", port=8080, debug=True)
