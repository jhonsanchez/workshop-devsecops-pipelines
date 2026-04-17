import sqlite3
from flask import request, jsonify
from src.utils.crypto import hash_password


def get_db():
    conn = sqlite3.connect("/tmp/app.db")
    conn.row_factory = sqlite3.Row
    return conn


def login():
    """Authenticate user — VULNERABLE: SQL Injection (CWE-89)"""
    username = request.form.get("username", "")
    password = request.form.get("password", "")
    password_hash = hash_password(password)

    db = get_db()
    # VULNERABLE: String formatting in SQL query allows injection
    query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password_hash}'"
    user = db.execute(query).fetchone()

    if user:
        return jsonify({"status": "ok", "user": user["username"]}), 200
    return jsonify({"status": "error", "message": "Invalid credentials"}), 401


def register():
    """Register new user — VULNERABLE: No input validation"""
    username = request.form.get("username", "")
    password = request.form.get("password", "")
    email = request.form.get("email", "")

    db = get_db()
    password_hash = hash_password(password)
    # VULNERABLE: SQL injection in INSERT
    db.execute(
        f"INSERT INTO users (username, password, email) VALUES ('{username}', '{password_hash}', '{email}')"
    )
    db.commit()
    return jsonify({"status": "created"}), 201
