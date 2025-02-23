package app

import (
	"log"
	"net/http"
	"trading-service/internal/config"
	"trading-service/internal/database"
	"trading-service/internal/model"
	"trading-service/internal/repository"
	ws "trading-service/internal/websocket"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

type Server struct {
	router    *gin.Engine
	orderRepo *repository.OrderRepository
	hub       *ws.Hub
	upgrader  websocket.Upgrader
}

func NewServer(cfg *config.Config) *Server {
	db, err := database.NewConnection(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	hub := ws.NewHub()
	go hub.Run()

	return &Server{
		router:    gin.Default(),
		orderRepo: repository.NewOrderRepository(db),
		hub:       hub,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
	}
}

func (s *Server) Run() error {
	s.setupRoutes()
	return s.router.Run(":8080")
}

func (s *Server) setupRoutes() {
	s.router.POST("/orders", s.createOrder)
	s.router.GET("/orders", s.getOrders)
	s.router.GET("/ws", s.handleWebSocket)
}

func (s *Server) createOrder(c *gin.Context) {
	var orderCreate model.OrderCreate
	if err := c.ShouldBindJSON(&orderCreate); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	order, err := s.orderRepo.Create(&orderCreate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order"})
		return
	}

	// Broadcast order creation to WebSocket clients
	s.hub.Broadcast <- []byte(order.Symbol + " order created")

	c.JSON(http.StatusCreated, order)
}

func (s *Server) getOrders(c *gin.Context) {
	orders, err := s.orderRepo.GetAll()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch orders"})
		return
	}

	c.JSON(http.StatusOK, orders)
}

func (s *Server) handleWebSocket(c *gin.Context) {
	conn, err := s.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("Failed to upgrade connection: %v", err)
		return
	}

	client := &ws.Client{
		Hub:  s.hub,
		Conn: conn,
		Send: make(chan []byte, 256),
	}
	client.Hub.Register <- client

	go func() {
		defer func() {
			client.Hub.Unregister <- client
			client.Conn.Close()
		}()

		for {
			_, _, err := conn.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					log.Printf("WebSocket error: %v", err)
				}
				break
			}
		}
	}()

	go func() {
		defer client.Conn.Close()
		for message := range client.Send {
			if err := client.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}
		}
		client.Conn.WriteMessage(websocket.CloseMessage, []byte{})
	}()
}
