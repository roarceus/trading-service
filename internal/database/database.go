package database

import (
	"database/sql"
	"fmt"
	"log"
	"trading-service/internal/config"

	_ "github.com/lib/pq"
)

func NewConnection(cfg *config.Config) (*sql.DB, error) {
	connStr := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName,
	)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("error opening database: %w", err)
	}

	if err = db.Ping(); err != nil {
		return nil, fmt.Errorf("error connecting to database: %w", err)
	}

	if err = initializeDatabase(db); err != nil {
		return nil, fmt.Errorf("error initializing database: %w", err)
	}

	return db, nil
}

func initializeDatabase(db *sql.DB) error {
	// Drop existing table if it exists
	dropTableSQL := `
    DROP TABLE IF EXISTS orders CASCADE;
    `

	if _, err := db.Exec(dropTableSQL); err != nil {
		return fmt.Errorf("error dropping table: %w", err)
	}

	// Create orders table
	createTableSQL := `
    CREATE TABLE orders (
        id SERIAL PRIMARY KEY,
        symbol VARCHAR(10) NOT NULL,
        price DECIMAL(10,2) NOT NULL,
        quantity INTEGER NOT NULL,
        order_type VARCHAR(4) NOT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
    `

	if _, err := db.Exec(createTableSQL); err != nil {
		return fmt.Errorf("error creating table: %w", err)
	}

	log.Println("Database initialized successfully")
	return nil
}
