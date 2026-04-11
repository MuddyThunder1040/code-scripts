import os
import hashlib
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
import psycopg2.extras
from contextlib import contextmanager

app = FastAPI(title="User Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "ecommerce")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "postgres")
USER_SERVICE_VERSION = os.environ.get("USER_SERVICE_VERSION", "blue")


def get_db_connection():
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )
    return conn


@contextmanager
def db_cursor():
    conn = get_db_connection()
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        yield cur, conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def create_tables():
    with db_cursor() as (cur, conn):
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(255) NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)
        print("Users table ready.")


@app.on_event("startup")
def startup_event():
    import time
    retries = 5
    for i in range(retries):
        try:
            create_tables()
            break
        except Exception as e:
            print(f"DB connection attempt {i+1} failed: {e}")
            if i < retries - 1:
                time.sleep(3)
            else:
                raise


class RegisterRequest(BaseModel):
    username: str
    email: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "user-service",
        "version": USER_SERVICE_VERSION,
    }


@app.post("/users/register")
def register(req: RegisterRequest):
    password_hash = hash_password(req.password)
    with db_cursor() as (cur, conn):
        try:
            cur.execute(
                "INSERT INTO users (username, email, password_hash) VALUES (%s, %s, %s) RETURNING id, username, email, created_at",
                (req.username, req.email, password_hash),
            )
            user = dict(cur.fetchone())
            user["created_at"] = str(user["created_at"])
            return user
        except psycopg2.errors.UniqueViolation:
            raise HTTPException(status_code=400, detail="Email already registered")


@app.post("/users/login")
def login(req: LoginRequest):
    password_hash = hash_password(req.password)
    with db_cursor() as (cur, conn):
        cur.execute(
            "SELECT id, username, email FROM users WHERE email = %s AND password_hash = %s",
            (req.email, password_hash),
        )
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        user = dict(user)
        return {
            "token": f"fake-jwt-{user['id']}",
            "user_id": user["id"],
            "username": user["username"],
        }


@app.get("/users/{user_id}")
def get_user(user_id: int):
    with db_cursor() as (cur, conn):
        cur.execute(
            "SELECT id, username, email, created_at FROM users WHERE id = %s",
            (user_id,),
        )
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        user = dict(user)
        user["created_at"] = str(user["created_at"])
        return user


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
