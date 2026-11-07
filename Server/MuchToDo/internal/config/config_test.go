package config

import (
    "testing"
)

func TestLoadConfigFromEnvironment(t *testing.T) {
    t.Setenv("PORT", "9090")
    t.Setenv("MONGO_URI", "mongodb://localhost:27017")
    t.Setenv("DB_NAME", "test_database")
    t.Setenv("JWT_SECRET_KEY", "test-secret")

    cfg, err := LoadConfig(t.TempDir())
    if err != nil {
        t.Fatalf("LoadConfig failed: %v", err)
    }

    if cfg.ServerPort != "9090" {
        t.Errorf("Expected port 9090, got %s", cfg.ServerPort)
    }

    if cfg.MongoURI != "mongodb://localhost:27017" {
        t.Errorf("Unexpected MongoDB URI")
    }

    if cfg.DBName != "test_database" {
        t.Errorf("Expected test_database, got %s", cfg.DBName)
    }

    if cfg.JWTSecretKey != "test-secret" {
        t.Errorf("JWT secret was not loaded")
    }
}