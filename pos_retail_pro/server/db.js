const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

const { DB_HOST = '127.0.0.1', DB_PORT = '3306', DB_USER = 'root', DB_PASSWORD = '', DB_NAME = 'pos_retail_pro' } = process.env;
let pool;

async function init() {
  // 1) make sure the database exists
  const boot = await mysql.createConnection({
    host: DB_HOST, port: +DB_PORT, user: DB_USER, password: DB_PASSWORD,
    connectTimeout: 10000,
  });
  await boot.query(`CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await boot.end();
  // 2) pool + tables
  pool = mysql.createPool({
    host: DB_HOST, port: +DB_PORT, user: DB_USER, password: DB_PASSWORD, database: DB_NAME,
    timezone: 'Z', waitForConnections: true, connectionLimit: 10, multipleStatements: true,
    connectTimeout: 10000,
  });
  await pool.query(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8'));
  return pool;
}

module.exports = { init, q: (...a) => pool.query(...a), getPool: () => pool };
