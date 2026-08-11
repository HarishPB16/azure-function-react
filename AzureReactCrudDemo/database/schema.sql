CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO products (name, description, price) VALUES
  ('Laptop', 'Development laptop', 75000.00),
  ('Mouse', 'Wireless mouse', 1500.00),
  ('Keyboard', 'Mechanical keyboard', 4500.00)
ON CONFLICT DO NOTHING;
