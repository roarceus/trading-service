package repository

import (
	"database/sql"
	"fmt"
	"trading-service/internal/model"
)

type OrderRepository struct {
	db *sql.DB
}

func NewOrderRepository(db *sql.DB) *OrderRepository {
	return &OrderRepository{db: db}
}

func (r *OrderRepository) Create(order *model.OrderCreate) (*model.Order, error) {
	query := `
        INSERT INTO orders (symbol, price, quantity, order_type)
        VALUES ($1, $2, $3, $4)
        RETURNING id, symbol, price, quantity, order_type, status, created_at, updated_at
    `

	var newOrder model.Order
	err := r.db.QueryRow(
		query,
		order.Symbol,
		order.Price,
		order.Quantity,
		order.OrderType,
	).Scan(
		&newOrder.ID,
		&newOrder.Symbol,
		&newOrder.Price,
		&newOrder.Quantity,
		&newOrder.OrderType,
		&newOrder.Status,
		&newOrder.CreatedAt,
		&newOrder.UpdatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("error creating order: %w", err)
	}

	return &newOrder, nil
}

func (r *OrderRepository) GetAll() ([]model.Order, error) {
	query := `
        SELECT id, symbol, price, quantity, order_type, status, created_at, updated_at
        FROM orders
        ORDER BY created_at DESC
    `

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("error querying orders: %w", err)
	}
	defer rows.Close()

	var orders []model.Order
	for rows.Next() {
		var order model.Order
		err := rows.Scan(
			&order.ID,
			&order.Symbol,
			&order.Price,
			&order.Quantity,
			&order.OrderType,
			&order.Status,
			&order.CreatedAt,
			&order.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("error scanning order: %w", err)
		}
		orders = append(orders, order)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating orders: %w", err)
	}

	return orders, nil
}
