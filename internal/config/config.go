package config

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
}

func Load() (*Config, error) {
	envLocations := []string{
		".env",                      // Current directory
		"/opt/trading-service/.env", // System directory
		"../.env",                   // Parent directory
	}

	var loaded bool
	for _, loc := range envLocations {
		if _, err := os.Stat(loc); err == nil {
			if err := godotenv.Load(loc); err == nil {
				loaded = true
				break
			}
		}
	}

	if !loaded {
		return nil, fmt.Errorf("no environment file found")
	}

	return &Config{
		DBHost:     os.Getenv("DB_HOST"),
		DBPort:     os.Getenv("DB_PORT"),
		DBUser:     os.Getenv("DB_USER"),
		DBPassword: os.Getenv("DB_PASSWORD"),
		DBName:     os.Getenv("DB_NAME"),
	}, nil
}
