package middleware

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/golang/glog"
	"github.com/livepeer/ai-worker/worker"
	"github.com/livepool-io/openai-middleware/common"
	"github.com/livepool-io/openai-middleware/models"
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
	// TODO: on gateway creation fetch from gateway and store
	// then return them here
	// TODO: then we can also add a check that the gateway has the capabilities
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

	client := &http.Client{}
	return client.Do(httpReq)
}

func HandleStreamingResponse(ctx context.Context, resp *http.Response) (<-chan models.OpenAIStreamResponse, <-chan error) {
	streamChan := make(chan models.OpenAIStreamResponse)
	errChan := make(chan error, 1) // Buffered channel to avoid goroutine leak

	go func() {
		defer close(streamChan)
		defer close(errChan)

		streamID := common.GenerateUniqueID()
		scanner := bufio.NewScanner(resp.Body)
		var totalTokens int

		for scanner.Scan() {
			select {
			case <-ctx.Done():
				errChan <- ctx.Err()
				return
			default:
				line := scanner.Text()
				if !strings.HasPrefix(line, "data: ") {
					continue
				}

				data := strings.TrimPrefix(line, "data: ")
				if data == "[DONE]" {
					chunk := worker.LlmStreamChunk{Chunk: "DONE", Done: true, TokensUsed: totalTokens}
					openAIChunk, err := common.TransformStreamResponse(chunk, streamID)
					if err != nil {
						errChan <- fmt.Errorf("error converting final chunk: %w", err)
						return
					}
					streamChan <- openAIChunk
					return
				}

				var chunk worker.LlmStreamChunk
				if err := json.Unmarshal([]byte(data), &chunk); err != nil {
					errChan <- fmt.Errorf("error unmarshalling SSE chunk: %w", err)
					continue
				}

				totalTokens += chunk.TokensUsed
				openAIChunk, err := common.TransformStreamResponse(chunk, streamID)
				if err != nil {
					errChan <- fmt.Errorf("error converting chunk: %w", err)
					return
				}

				streamChan <- openAIChunk
			}
		}

		if err := scanner.Err(); err != nil {
			errChan <- fmt.Errorf("error reading SSE stream: %w", err)
		}
	}()

	return streamChan, errChan
}

func (g *Gateway) HandleStreamingResponse(w http.ResponseWriter, r *http.Request, resp *http.Response) error {
	ctx := r.Context()
	streamChan, errChan := common.HandleStreamingResponse(ctx, resp)

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	for {
		select {
		case <-ctx.Done():
			glog.Warning("Client connection closed")
			return nil
		case err := <-errChan:
			if err != io.EOF {
				glog.Errorf("Error in streaming response: %v", err)
			}
			return err
		case chunk, ok := <-streamChan:
			if !ok {
				return fmt.Errorf("stream closed")
			}

			data, err := json.Marshal(chunk)
			if err != nil {
				glog.Errorf("Error marshalling OpenAI chunk: %v", err)
				return err
			}

			_, err = fmt.Fprintf(w, "data: %s\n\n", data)
			if err != nil {
				glog.Errorf("Error writing to response: %v", err)
				return err
			}
			w.(http.Flusher).Flush()
		}
	}
}
