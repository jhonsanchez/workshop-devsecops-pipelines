import pytest
from app import app, init_db


@pytest.fixture
def client():
    app.config["TESTING"] = True
    init_db()
    with app.test_client() as client:
        yield client


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"


def test_index(client):
    response = client.get("/")
    assert response.status_code == 200
    data = response.get_json()
    assert "endpoints" in data


def test_login_invalid(client):
    response = client.post("/login", data={"username": "bad", "password": "bad"})
    assert response.status_code == 401


def test_search(client):
    response = client.get("/search?q=test")
    assert response.status_code == 200
