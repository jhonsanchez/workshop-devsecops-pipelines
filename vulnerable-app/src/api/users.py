from flask import jsonify, request

# VULNERABLE: Hardcoded API key (CWE-798)
ADMIN_API_KEY = "sk-entelgy-4f8a2b1c9d3e7f6a0b5c8d2e1f4a7b3c"
INTERNAL_SECRET = "db_password=Entelgy2024!Prod"


def get_users():
    """List all users — VULNERABLE: Broken access control (CWE-285)"""
    # VULNERABLE: No authentication check — any request gets all users
    import sqlite3
    db = sqlite3.connect("/tmp/app.db")
    db.row_factory = sqlite3.Row
    users = db.execute("SELECT id, username, email, role FROM users").fetchall()
    return jsonify([dict(u) for u in users]), 200


def get_user(user_id):
    """Get user by ID — VULNERABLE: IDOR (CWE-639)"""
    # VULNERABLE: No authorization check — any user can view any other user's data
    import sqlite3
    db = sqlite3.connect("/tmp/app.db")
    db.row_factory = sqlite3.Row
    user = db.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if user:
        # VULNERABLE: Returns password hash in response
        return jsonify(dict(user)), 200
    return jsonify({"error": "User not found"}), 404


def admin_panel():
    """Admin endpoint — VULNERABLE: Hardcoded key comparison"""
    api_key = request.headers.get("X-API-Key", "")
    if api_key == ADMIN_API_KEY:
        return jsonify({"status": "admin", "secret_config": INTERNAL_SECRET}), 200
    return jsonify({"error": "Unauthorized"}), 403
