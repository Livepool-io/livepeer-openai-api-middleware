// server/server.go

package server

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/livepool-io/openai-middleware/common"
	"github.com/livepool-io/openai-middleware/db"
	"github.com/livepool-io/openai-middleware/middleware"
	"github.com/livepool-io/openai-middleware/models"
)

type Server struct {
	db      *db.APIKeyStore
	gateway *middleware.Gateway
}

func NewServer(apiKeys *db.APIKeyStore, gateway *middleware.Gateway) (*Server, error) {
	if gateway == nil {
		return nil, fmt.Errorf("gateway is required")
	}
	return &Server{
		gateway: gateway,
	}, nil
}

func (s *Server) Start(port string) error {
	r := gin.Default()
	protected := r.Group("/")
	protected.Use(s.authRequired())
	{
		protected.POST("/v1/chat/completions", s.handleChatCompletion)
		protected.POST("/v1/completions", s.handleCompletion)
	}
	r.GET("/v1/models", s.handleModels)
	r.GET("/v1/embeddings", s.handleEmbeddings)
	r.GET("/health", s.handleHealth)
	err := r.Run(":" + port)
	if err != nil {
		return err
	}

	fmt.Printf("Server is running on :%s\n", port)
	return http.ListenAndServe(":"+port, nil)
}

func (s *Server) handleChatCompletion(c *gin.Context) {
	var openAIReq models.OpenAIRequest
	if err := c.ShouldBindJSON(&openAIReq); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	// Transform OpenAI request to our Gateway API format
	req, err := common.TransformRequest(openAIReq)
	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	// Check usage allowed
	apiKeyI, ok := c.Get("apiKey")
	if !ok {
		c.JSON(500, gin.H{"error": "API key not found"})
		return
	}
	apiKey := apiKeyI.(*db.APIKeyModel)
	// check usage allowed
	ok, err = s.db.CheckUsageLimit(c, apiKey.UserID, *req.MaxTokens)
	if err != nil {
		c.JSON(429, gin.H{"error": err.Error()})
		return
	}
	if !ok {
		c.JSON(429, gin.H{"error": "Usage limit exceeded"})
		return
	}

	// Call gateway
	resp, err := s.gateway.PostLlmGenerate(*req)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	var tokensUsed int
	if openAIReq.Stream {
		c.Header("Content-Type", "text/event-stream")
		c.Header("Cache-Control", "no-cache")
		c.Header("Connection", "keep-alive")

		streamChan, errChan := common.HandleStreamingResponse(c.Request.Context(), req, resp)

		for {
			select {
			case <-c.Request.Context().Done():
				return
			case err := <-errChan:
				if err != io.EOF {
					c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				}
				return
			case chunk := <-streamChan:
				data, err := json.Marshal(chunk)
				if err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
					return
				}

				_, err = fmt.Fprintf(c.Writer, "data: %s\n\n", data)
				if err != nil {
					return
				}
				c.Writer.(http.Flusher).Flush()

				// Record usage when we get the final chunk
				if chunk.Choices[0].FinishReason == "stop" && chunk.Usage != nil {
					tokensUsed = chunk.Usage.TotalTokens
				}
			}
		}
	} else {
		// Handle non-streaming response
		openAIResp, err := common.TransformResponse(req, resp)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		tokensUsed = openAIResp.Usage.TotalTokens

		c.JSON(http.StatusOK, openAIResp)
	}

	go func() {
		if err := s.db.RecordAPIUsage(context.Background(),
			apiKey.ID,
			apiKey.UserID,
			tokensUsed); err != nil {
			log.Printf("Failed to record API usage: %v", err)
		}
	}()
}

func (s *Server) handleCompletion(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{"error": "Not implemented"})
}

func (s *Server) handleModels(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"models": s.gateway.GetModels()})
}

func (s *Server) handleEmbeddings(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{"error": "Not implemented"})
}

func (s *Server) handleHealth(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func (s *Server) authRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		apiKey := c.GetHeader("X-API-Key")
		if apiKey == "" {
			c.JSON(401, gin.H{"error": "API key is required"})
			c.Abort()
			return
		}

		key, err := s.db.ValidateAndGetAPIKey(c, apiKey)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			c.Abort()
			return
		}

		c.Set("apiKey", key)
		c.Next()
	}
}
