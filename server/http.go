// server/server.go

package server

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/livepool-io/openai-middleware/common"
	"github.com/livepool-io/openai-middleware/middleware"
	"github.com/livepool-io/openai-middleware/models"
)

type Server struct {
	// We can add fields here later if needed, such as a database connection
	gateway *middleware.Gateway
}

func NewServer(gateway *middleware.Gateway) (*Server, error) {
	if gateway == nil {
		return nil, fmt.Errorf("gateway is required")
	}
	return &Server{
		gateway: gateway,
	}, nil
}

func (s *Server) Start(port string) error {
	r := gin.Default()
	r.POST("/v1/chat/completions", s.handleChatCompletion)
	r.POST("/v1/completions", s.handleCompletion)
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

	// Call gateway
	resp, err := s.gateway.PostLlmGenerate(*req)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	if openAIReq.Stream {
		c.Header("Content-Type", "text/event-stream")
		c.Header("Cache-Control", "no-cache")
		c.Header("Connection", "keep-alive")

		// Handle streaming response and
		// forward stream to caller in OpenAPI format
		if err := s.gateway.HandleStreamingResponse(c.Request.Context(), req, c.Writer, resp); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	} else {
		// Transform Gateway API response to OpenAI format
		openAIResp, err := common.TransformResponse(req, resp)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, openAIResp)
	}
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
