-- Tables are created automatically when the server starts (CREATE TABLE IF NOT EXISTS).
-- You can also run this file in phpMyAdmin > SQL after creating the database `pos_retail_pro`.

CREATE TABLE IF NOT EXISTS users (
  id            VARCHAR(36)  PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(100) NOT NULL,
  role          ENUM('owner','cashier') NOT NULL DEFAULT 'cashier',
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
  id         VARCHAR(36)  PRIMARY KEY,
  name       VARCHAR(150) NOT NULL,
  price      INT NOT NULL,
  stock      INT NOT NULL DEFAULT 0,
  reorder    INT NOT NULL DEFAULT 10,
  category   VARCHAR(50)  NOT NULL DEFAULT 'Other',
  image      VARCHAR(255) NOT NULL DEFAULT '',
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS customers (
  id         VARCHAR(36)  PRIMARY KEY,
  name       VARCHAR(150) NOT NULL,
  phone      VARCHAR(40)  NOT NULL DEFAULT '',
  email      VARCHAR(150) NOT NULL DEFAULT '',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sales (
  id          VARCHAR(36)  PRIMARY KEY,          -- made on the device, so offline sales are safe to re-upload
  receipt     VARCHAR(40)  NOT NULL,
  total       INT NOT NULL,
  tax         INT NOT NULL,
  method      VARCHAR(30)  NOT NULL,
  customer    VARCHAR(150) NOT NULL DEFAULT 'Walk-in Customer',
  user_id     VARCHAR(36)  NULL,
  paypal_ref  VARCHAR(60)  NULL,
  created_at  DATETIME     NOT NULL,             -- stored in UTC
  INDEX idx_sales_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sale_items (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  sale_id    VARCHAR(36)  NOT NULL,
  product_id VARCHAR(36)  NOT NULL,
  name       VARCHAR(150) NOT NULL,
  price      INT NOT NULL,
  qty        INT NOT NULL,
  INDEX idx_items_sale (sale_id),
  FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
) ENGINE=InnoDB;
