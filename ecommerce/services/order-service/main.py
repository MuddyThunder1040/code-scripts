import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import psycopg2
import psycopg2.extras
from contextlib import contextmanager

app = FastAPI(title="Order Service", version="1.0.0")

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
ORDER_SERVICE_VERSION = os.environ.get("ORDER_SERVICE_VERSION", "blue")

VALID_STATUSES = {"pending", "processing", "shipped", "delivered", "cancelled"}


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


def create_tables():
    with db_cursor() as (cur, conn):
        cur.execute("""
            CREATE TABLE IF NOT EXISTS orders (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL,
                status VARCHAR(50) DEFAULT 'pending',
                total DECIMAL(10,2) NOT NULL,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS order_items (
                id SERIAL PRIMARY KEY,
                order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
                product_id INTEGER NOT NULL,
                quantity INTEGER NOT NULL,
                price DECIMAL(10,2) NOT NULL
            )
        """)
        print("Orders tables ready.")


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


class OrderItem(BaseModel):
    product_id: int
    quantity: int
    price: float


class CreateOrderRequest(BaseModel):
    user_id: int
    items: List[OrderItem]


class UpdateStatusRequest(BaseModel):
    status: str


def serialize_order(order: dict) -> dict:
    o = dict(order)
    if o.get("created_at"):
        o["created_at"] = str(o["created_at"])
    if o.get("total") is not None:
        o["total"] = float(o["total"])
    return o


def serialize_item(item: dict) -> dict:
    i = dict(item)
    if i.get("price") is not None:
        i["price"] = float(i["price"])
    return i


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "order-service",
        "version": ORDER_SERVICE_VERSION,
    }


@app.post("/orders", status_code=201)
def create_order(req: CreateOrderRequest):
    if not req.items:
        raise HTTPException(status_code=400, detail="Order must have at least one item")
    total = sum(item.price * item.quantity for item in req.items)
    with db_cursor() as (cur, conn):
        cur.execute(
            "INSERT INTO orders (user_id, status, total) VALUES (%s, 'pending', %s) RETURNING *",
            (req.user_id, total),
        )
        order = dict(cur.fetchone())
        order_id = order["id"]
        items = []
        for item in req.items:
            cur.execute(
                "INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (%s, %s, %s, %s) RETURNING *",
                (order_id, item.product_id, item.quantity, item.price),
            )
            items.append(serialize_item(cur.fetchone()))
        result = serialize_order(order)
        result["items"] = items
        return result


@app.get("/orders/{order_id}")
def get_order(order_id: int):
    with db_cursor() as (cur, conn):
        cur.execute("SELECT * FROM orders WHERE id = %s", (order_id,))
        order = cur.fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        cur.execute("SELECT * FROM order_items WHERE order_id = %s", (order_id,))
        items = [serialize_item(i) for i in cur.fetchall()]
        result = serialize_order(order)
        result["items"] = items
        return result


@app.get("/orders/user/{user_id}")
def get_user_orders(user_id: int):
    with db_cursor() as (cur, conn):
        cur.execute("SELECT * FROM orders WHERE user_id = %s ORDER BY created_at DESC", (user_id,))
        orders = cur.fetchall()
        result = []
        for order in orders:
            order_dict = serialize_order(order)
            cur.execute("SELECT * FROM order_items WHERE order_id = %s", (order_dict["id"],))
            order_dict["items"] = [serialize_item(i) for i in cur.fetchall()]
            result.append(order_dict)
        return result


@app.put("/orders/{order_id}/status")
def update_order_status(order_id: int, req: UpdateStatusRequest):
    if req.status not in VALID_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status. Must be one of: {', '.join(VALID_STATUSES)}",
        )
    with db_cursor() as (cur, conn):
        cur.execute(
            "UPDATE orders SET status = %s WHERE id = %s RETURNING *",
            (req.status, order_id),
        )
        order = cur.fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        cur.execute("SELECT * FROM order_items WHERE order_id = %s", (order_id,))
        items = [serialize_item(i) for i in cur.fetchall()]
        result = serialize_order(order)
        result["items"] = items
        return result


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003)
