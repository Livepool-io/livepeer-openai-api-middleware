package middleware

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/livepeer/ai-worker/worker"
	"github.com/livepool-io/openai-middleware/common"
)

type Gateway struct {
	url           string
	defaultModels map[string]string // piepeline -> model
}

func NewGateway(url string) *Gateway {
	return &Gateway{
		url: url,
		defaultModels: map[string]string{
			"llm-generate": "meta-llama/Llama-3.1-8B-Instruct",
		},
	}
}

func (g *Gateway) GetModels() map[string]string {
	return g.defaultModels
}

func (g *Gateway) PostLlmGenerate(req worker.LlmGenerateFormdataRequestBody) (*http.Response, error) {
	var body bytes.Buffer
	mw, err := worker.NewLlmGenerateMultipartWriter(&body, req)
	if err != nil {
		return nil, err
	}
	defer mw.Close()
	httpReq, err := http.NewRequest("POST", g.url+"/llm-generate", &body)
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "multipart/form-data")

	client := &http.Client{}
	return client.Do(httpReq)
}

func (g *Gateway) HandleStreamingResponse(w http.ResponseWriter, resp *http.Response) error {
	// Implement streaming response handling
	// TODO: OpenAPI return format
	errChan := make(chan error)
	defer close(errChan)
	streamChan := make(chan worker.LlmStreamChunk, 100)
	go func() {
		defer close(streamChan)
		scanner := bufio.NewScanner(resp.Body)
		var totalTokens int
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, "data: ") {
				data := strings.TrimPrefix(line, "data: ")
				if data == "[DONE]" {
					streamChan <- worker.LlmStreamChunk{Done: true, TokensUsed: totalTokens}
					break
				}
				var chunk worker.LlmStreamChunk
				if err := json.Unmarshal([]byte(data), &chunk); err != nil {
					errChan <- fmt.Errorf("error unmarshalling SSE chunk: %v", err)
					continue
				}
				totalTokens += chunk.TokensUsed
				streamChan <- chunk
			}
		}
		if err := scanner.Err(); err != nil {
			errChan <- fmt.Errorf("error reading SSE stream: %v", err)
		}
	}()

	// Handle streaming response (SSE)
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	for {
		select {
		case err := <-errChan:
			return err
		case chunk, ok := <-streamChan:
			if !ok {
				// Stream channel closed
				return nil
			}

			openAIChunk, err := common.TransformStreamResponse(chunk, common.GenerateUniqueID())
			if err != nil {
				return fmt.Errorf("error converting chunk to OpenAI format: %v", err)
			}

			data, err := json.Marshal(openAIChunk)
			if err != nil {
				return fmt.Errorf("error marshalling OpenAI chunk: %v", err)
			}

			_, err = fmt.Fprintf(w, "data: %s\n\n", data)
			if err != nil {
				return fmt.Errorf("error writing to response: %v", err)
			}
			w.(http.Flusher).Flush()

			if chunk.Done {
				_, err = fmt.Fprintf(w, "data: [DONE]\n\n")
				if err != nil {
					return fmt.Errorf("error writing DONE message: %v", err)
				}
				w.(http.Flusher).Flush()
				return nil
			}
		}
	}
}
