// middleware/auth.go

package middleware

import (
	"github.com/gin-gonic/gin"
)

type APIKeyStore interface {
	ValidateAPIKey(apiKey string) (bool, error)
}

type Auth struct {
	apiKeyStore APIKeyStore
}

func NewAuthMiddleware(apiKeyStore APIKeyStore) *Auth {
	return &Auth{apiKeyStore: apiKeyStore}
}

func (a *Auth) AuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		apiKey := c.GetHeader("X-API-Key")
		if apiKey == "" {
			c.JSON(401, gin.H{"error": "API key is required"})
			c.Abort()
			return
		}

		valid, err := a.apiKeyStore.ValidateAPIKey(apiKey)
		if err != nil {
			c.JSON(500, gin.H{"error": "Error checking API key"})
			c.Abort()
			return
		}

		if !valid {
			c.JSON(401, gin.H{"error": "Invalid API key"})
			c.Abort()
			return
		}

		c.Next()
	}
}
