import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import psycopg2
import psycopg2.extras
from contextlib import contextmanager

app = FastAPI(title="Product Service", version="1.0.0")

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
PRODUCT_SERVICE_VERSION = os.environ.get("PRODUCT_SERVICE_VERSION", "blue")

SAMPLE_PRODUCTS = [
    {"name": "iPhone 15 Pro", "description": "Latest Apple iPhone with A17 Pro chip, titanium design, and USB-C connectivity.", "price": 999.99, "stock": 50, "category": "Electronics", "image_url": "https://via.placeholder.com/300x300?text=iPhone+15+Pro"},
    {"name": "Samsung 65\" 4K QLED TV", "description": "Stunning 65-inch QLED display with 4K resolution, HDR10+, and smart TV features.", "price": 1299.99, "stock": 20, "category": "Electronics", "image_url": "https://via.placeholder.com/300x300?text=Samsung+TV"},
    {"name": "MacBook Pro 14\"", "description": "Apple MacBook Pro with M3 chip, 14-inch Liquid Retina XDR display, 16GB RAM, 512GB SSD.", "price": 1999.99, "stock": 30, "category": "Electronics", "image_url": "https://via.placeholder.com/300x300?text=MacBook+Pro"},
    {"name": "AirPods Pro 2nd Gen", "description": "Active noise cancellation, Adaptive Transparency, Personalized Spatial Audio with H2 chip.", "price": 249.99, "stock": 100, "category": "Electronics", "image_url": "https://via.placeholder.com/300x300?text=AirPods+Pro"},
    {"name": "Logitech G Pro X Gaming Mouse", "description": "Professional gaming mouse with HERO 25K sensor, 5-25,600 DPI, ultralight design.", "price": 79.99, "stock": 75, "category": "Electronics", "image_url": "https://via.placeholder.com/300x300?text=Gaming+Mouse"},
    {"name": "Nike Air Max 270", "description": "Iconic Nike sneakers with large Max Air unit, breathable mesh upper, foam midsole.", "price": 150.00, "stock": 60, "category": "Clothing", "image_url": "https://via.placeholder.com/300x300?text=Nike+Air+Max"},
    {"name": "Levi's 501 Original Jeans", "description": "Classic straight-fit jeans in 100% cotton denim, iconic button fly, timeless style.", "price": 69.99, "stock": 80, "category": "Clothing", "image_url": "https://via.placeholder.com/300x300?text=Levis+Jeans"},
    {"name": "Columbia Winter Jacket", "description": "Insulated winter jacket with Omni-Heat thermal reflective lining, water-resistant shell.", "price": 189.99, "stock": 40, "category": "Clothing", "image_url": "https://via.placeholder.com/300x300?text=Winter+Jacket"},
    {"name": "Premium Cotton T-Shirt Pack (5)", "description": "Pack of 5 premium 100% cotton t-shirts in assorted colors, crew neck, machine washable.", "price": 39.99, "stock": 150, "category": "Clothing", "image_url": "https://via.placeholder.com/300x300?text=T-Shirt+Pack"},
    {"name": "Under Armour Sports Shorts", "description": "Moisture-wicking sports shorts with 4-way stretch fabric, built-in compression liner.", "price": 34.99, "stock": 90, "category": "Clothing", "image_url": "https://via.placeholder.com/300x300?text=Sports+Shorts"},
]


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


def serialize_product(product: dict) -> dict:
    p = dict(product)
    if p.get("created_at"):
        p["created_at"] = str(p["created_at"])
    if p.get("price") is not None:
        p["price"] = float(p["price"])
    return p


def create_tables_and_seed():
    with db_cursor() as (cur, conn):
        cur.execute("""
            CREATE TABLE IF NOT EXISTS products (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                price DECIMAL(10,2) NOT NULL,
                stock INTEGER DEFAULT 0,
                category VARCHAR(100),
                image_url VARCHAR(500),
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)
        cur.execute("SELECT COUNT(*) FROM products")
        count = cur.fetchone()["count"]
        if count == 0:
            for product in SAMPLE_PRODUCTS:
                cur.execute(
                    "INSERT INTO products (name, description, price, stock, category, image_url) VALUES (%s, %s, %s, %s, %s, %s)",
                    (product["name"], product["description"], product["price"], product["stock"], product["category"], product["image_url"]),
                )
            print(f"Seeded {len(SAMPLE_PRODUCTS)} sample products.")
        else:
            print(f"Products table already has {count} records, skipping seed.")


@app.on_event("startup")
def startup_event():
    import time
    retries = 5
    for i in range(retries):
        try:
            create_tables_and_seed()
            break
        except Exception as e:
            print(f"DB connection attempt {i+1} failed: {e}")
            if i < retries - 1:
                time.sleep(3)
            else:
                raise


class ProductCreate(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    stock: int = 0
    category: Optional[str] = None
    image_url: Optional[str] = None


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    category: Optional[str] = None
    image_url: Optional[str] = None


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "product-service",
        "version": PRODUCT_SERVICE_VERSION,
    }


@app.get("/products")
def list_products():
    with db_cursor() as (cur, conn):
        cur.execute("SELECT * FROM products ORDER BY id")
        products = cur.fetchall()
        return [serialize_product(p) for p in products]


@app.get("/products/{product_id}")
def get_product(product_id: int):
    with db_cursor() as (cur, conn):
        cur.execute("SELECT * FROM products WHERE id = %s", (product_id,))
        product = cur.fetchone()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        return serialize_product(product)


@app.post("/products", status_code=201)
def create_product(req: ProductCreate):
    with db_cursor() as (cur, conn):
        cur.execute(
            "INSERT INTO products (name, description, price, stock, category, image_url) VALUES (%s, %s, %s, %s, %s, %s) RETURNING *",
            (req.name, req.description, req.price, req.stock, req.category, req.image_url),
        )
        product = cur.fetchone()
        return serialize_product(product)


@app.put("/products/{product_id}")
def update_product(product_id: int, req: ProductUpdate):
    with db_cursor() as (cur, conn):
        cur.execute("SELECT * FROM products WHERE id = %s", (product_id,))
        existing = cur.fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail="Product not found")
        existing = dict(existing)
        name = req.name if req.name is not None else existing["name"]
        description = req.description if req.description is not None else existing["description"]
        price = req.price if req.price is not None else existing["price"]
        stock = req.stock if req.stock is not None else existing["stock"]
        category = req.category if req.category is not None else existing["category"]
        image_url = req.image_url if req.image_url is not None else existing["image_url"]
        cur.execute(
            "UPDATE products SET name=%s, description=%s, price=%s, stock=%s, category=%s, image_url=%s WHERE id=%s RETURNING *",
            (name, description, price, stock, category, image_url, product_id),
        )
        product = cur.fetchone()
        return serialize_product(product)


@app.delete("/products/{product_id}")
def delete_product(product_id: int):
    with db_cursor() as (cur, conn):
        cur.execute("DELETE FROM products WHERE id = %s RETURNING id", (product_id,))
        deleted = cur.fetchone()
        if not deleted:
            raise HTTPException(status_code=404, detail="Product not found")
        return {"message": f"Product {product_id} deleted successfully"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
