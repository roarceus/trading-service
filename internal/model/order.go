package model

import (
	"time"
)

type OrderType string

const (
	OrderTypeBuy  OrderType = "BUY"
	OrderTypeSell OrderType = "SELL"
)

type Order struct {
	ID        int64     `json:"id"`
	Symbol    string    `json:"symbol"`
	Price     float64   `json:"price"`
	Quantity  int       `json:"quantity"`
	OrderType OrderType `json:"order_type"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type OrderCreate struct {
	Symbol    string    `json:"symbol" binding:"required"`
	Price     float64   `json:"price" binding:"required,gt=0"`
	Quantity  int       `json:"quantity" binding:"required,gt=0"`
	OrderType OrderType `json:"order_type" binding:"required,oneof=BUY SELL"`
}
