-- =============================================================
-- ShopCloud E-Commerce Database Initialization
-- =============================================================

-- Create database (when run via docker-entrypoint-initdb.d, the DB is already created)
-- POSTGRES_DB env var creates it; we just set it up here.

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ecommerce TO postgres;

-- =============================================================
-- USERS TABLE
-- =============================================================
CREATE TABLE IF NOT EXISTS users (
    id           SERIAL PRIMARY KEY,
    username     VARCHAR(255)        NOT NULL,
    email        VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255)       NOT NULL,
    created_at   TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- =============================================================
-- PRODUCTS TABLE
-- =============================================================
CREATE TABLE IF NOT EXISTS products (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255)     NOT NULL,
    description TEXT,
    price       DECIMAL(10,2)    NOT NULL,
    stock       INTEGER          DEFAULT 0,
    category    VARCHAR(100),
    image_url   VARCHAR(500),
    created_at  TIMESTAMP        DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_price     ON products(price);
CREATE INDEX IF NOT EXISTS idx_products_name      ON products USING gin(to_tsvector('english', name));

-- =============================================================
-- ORDERS TABLE
-- =============================================================
CREATE TABLE IF NOT EXISTS orders (
    id         SERIAL PRIMARY KEY,
    user_id    INTEGER       NOT NULL,
    status     VARCHAR(50)   DEFAULT 'pending',
    total      DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP     DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status  ON orders(status);

-- =============================================================
-- ORDER ITEMS TABLE
-- =============================================================
CREATE TABLE IF NOT EXISTS order_items (
    id         SERIAL PRIMARY KEY,
    order_id   INTEGER       REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER       NOT NULL,
    quantity   INTEGER       NOT NULL,
    price      DECIMAL(10,2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id   ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- =============================================================
-- SEED: 15 SAMPLE PRODUCTS
-- =============================================================
INSERT INTO products (name, description, price, stock, category, image_url) VALUES
-- Electronics
('iPhone 15 Pro',
 'Apple iPhone 15 Pro with A17 Pro chip, titanium design, USB-C port, 48MP camera system, and Dynamic Island.',
 999.99, 50, 'Electronics',
 'https://via.placeholder.com/300x300?text=iPhone+15+Pro'),

('Samsung 65" 4K QLED TV',
 'Samsung 65-inch QLED TV with 4K resolution, Quantum HDR, built-in Alexa, and 144Hz gaming mode.',
 1299.99, 20, 'Electronics',
 'https://via.placeholder.com/300x300?text=Samsung+TV'),

('MacBook Pro 14"',
 'Apple MacBook Pro 14-inch with M3 chip, 16GB unified memory, 512GB SSD, Liquid Retina XDR display.',
 1999.99, 30, 'Electronics',
 'https://via.placeholder.com/300x300?text=MacBook+Pro'),

('AirPods Pro 2nd Generation',
 'Active Noise Cancellation, Adaptive Transparency, Personalized Spatial Audio, USB-C charging case.',
 249.99, 100, 'Electronics',
 'https://via.placeholder.com/300x300?text=AirPods+Pro'),

('Logitech G Pro X Gaming Mouse',
 'Wireless gaming mouse with HERO 25K sensor, 60-hour battery, 5 programmable buttons, ultralight 60g.',
 79.99, 75, 'Electronics',
 'https://via.placeholder.com/300x300?text=Gaming+Mouse'),

-- Clothing
('Nike Air Max 270',
 'Lifestyle shoe with the largest Max Air unit yet for all-day comfort. Breathable mesh upper.',
 150.00, 60, 'Clothing',
 'https://via.placeholder.com/300x300?text=Nike+Air+Max'),

('Levi''s 501 Original Fit Jeans',
 'The original jean since 1873. Straight leg, button fly, sits at the waist. 100% cotton denim.',
 69.99, 80, 'Clothing',
 'https://via.placeholder.com/300x300?text=Levis+501'),

('Columbia Whirlibird IV Interchange Jacket',
 'Waterproof, breathable, and warm. Omni-Heat Infinity thermal reflective lining. Zip-in/zip-out liner.',
 189.99, 40, 'Clothing',
 'https://via.placeholder.com/300x300?text=Winter+Jacket'),

('Hanes Premium Cotton T-Shirt Pack (5)',
 'Pack of 5 heavyweight 100% cotton crew-neck t-shirts. Pre-shrunk, tagless, machine washable. Sizes S-3XL.',
 39.99, 150, 'Clothing',
 'https://via.placeholder.com/300x300?text=T-Shirt+5-Pack'),

('Under Armour HeatGear Sports Shorts',
 '4-way stretch fabric, moisture-wicking, built-in compression liner, pockets. 9" inseam.',
 34.99, 90, 'Clothing',
 'https://via.placeholder.com/300x300?text=Sports+Shorts'),

-- Books
('Clean Code: A Handbook of Agile Software Craftsmanship',
 'Robert C. Martin''s guide to writing clean, readable, and maintainable code. Essential for all developers.',
 35.99, 200, 'Books',
 'https://via.placeholder.com/300x300?text=Clean+Code'),

('The DevOps Handbook',
 'How to Create World-Class Agility, Reliability, and Security in Technology Organizations. By Gene Kim et al.',
 42.99, 180, 'Books',
 'https://via.placeholder.com/300x300?text=DevOps+Handbook'),

('Kubernetes in Action, 2nd Edition',
 'Comprehensive guide to deploying, managing, and scaling containerized applications with Kubernetes.',
 55.99, 120, 'Books',
 'https://via.placeholder.com/300x300?text=Kubernetes+in+Action'),

('Designing Data-Intensive Applications',
 'Martin Kleppmann''s deep dive into the principles behind reliable, scalable, and maintainable systems.',
 49.99, 160, 'Books',
 'https://via.placeholder.com/300x300?text=DDIA'),

('The Pragmatic Programmer: 20th Anniversary Edition',
 'Your journey to mastery. Timeless lessons on software craftsmanship by David Thomas and Andrew Hunt.',
 44.99, 140, 'Books',
 'https://via.placeholder.com/300x300?text=Pragmatic+Programmer')

ON CONFLICT DO NOTHING;
