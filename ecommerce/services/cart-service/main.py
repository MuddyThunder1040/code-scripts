import os
import json
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import redis

app = FastAPI(title="Cart Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
CART_SERVICE_VERSION = os.environ.get("CART_SERVICE_VERSION", "blue")

redis_client: Optional[redis.Redis] = None


def get_redis():
    global redis_client
    if redis_client is None:
        redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
    return redis_client


def cart_key(user_id: int) -> str:
    return f"cart:{user_id}"


def get_cart_items(user_id: int) -> list:
    r = get_redis()
    data = r.get(cart_key(user_id))
    if data is None:
        return []
    return json.loads(data)


def save_cart_items(user_id: int, items: list):
    r = get_redis()
    r.set(cart_key(user_id), json.dumps(items))


@app.on_event("startup")
def startup_event():
    import time
    retries = 5
    for i in range(retries):
        try:
            r = get_redis()
            r.ping()
            print("Redis connection established.")
            break
        except Exception as e:
            print(f"Redis connection attempt {i+1} failed: {e}")
            if i < retries - 1:
                time.sleep(3)
            else:
                raise


class CartItem(BaseModel):
    product_id: int
    quantity: int
    price: float
    name: str


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "cart-service",
        "version": CART_SERVICE_VERSION,
    }


@app.get("/cart/{user_id}")
def get_cart(user_id: int):
    items = get_cart_items(user_id)
    return {"user_id": user_id, "items": items}


@app.post("/cart/{user_id}/items")
def add_item_to_cart(user_id: int, item: CartItem):
    items = get_cart_items(user_id)
    existing_index = None
    for idx, existing_item in enumerate(items):
        if existing_item["product_id"] == item.product_id:
            existing_index = idx
            break
    if existing_index is not None:
        items[existing_index]["quantity"] += item.quantity
        items[existing_index]["price"] = item.price
        items[existing_index]["name"] = item.name
    else:
        items.append({
            "product_id": item.product_id,
            "quantity": item.quantity,
            "price": item.price,
            "name": item.name,
        })
    save_cart_items(user_id, items)
    return {"user_id": user_id, "items": items}


@app.delete("/cart/{user_id}/items/{product_id}")
def remove_item_from_cart(user_id: int, product_id: int):
    items = get_cart_items(user_id)
    new_items = [i for i in items if i["product_id"] != product_id]
    if len(new_items) == len(items):
        raise HTTPException(status_code=404, detail="Item not found in cart")
    save_cart_items(user_id, new_items)
    return {"user_id": user_id, "items": new_items}


@app.delete("/cart/{user_id}")
def clear_cart(user_id: int):
    r = get_redis()
    r.delete(cart_key(user_id))
    return {"user_id": user_id, "message": "Cart cleared", "items": []}


@app.get("/cart/{user_id}/total")
def get_cart_total(user_id: int):
    items = get_cart_items(user_id)
    total = sum(item["price"] * item["quantity"] for item in items)
    item_count = sum(item["quantity"] for item in items)
    return {
        "user_id": user_id,
        "total": round(total, 2),
        "item_count": item_count,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8004)
