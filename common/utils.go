package common

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/livepeer/ai-worker/worker"
	"github.com/livepool-io/openai-middleware/models"
)

func historyFromMessages(messages []models.OpenAIMessage) (*string, error) {
	if len(messages) <= 1 {
		str := "[]"
		return &str, nil
	}
	messages = messages[1 : len(messages)-1]
	var history []*string
	for _, message := range messages {
		msg := fmt.Sprintf("%s: %s", message.Role, message.Content)
		history = append(history, &msg)
	}
	historyB, err := json.Marshal(history)
	var historyStr string
	if err != nil {
		return &historyStr, err
	}
	historyStr = string(historyB)
	return &historyStr, nil
}

func TransformRequest(openAIReq models.OpenAIRequest) (*worker.LlmGenerateFormdataRequestBody, error) {

	llmReq := worker.LlmGenerateFormdataRequestBody{
		ModelId: &openAIReq.Model,
		Prompt:  openAIReq.Messages[len(openAIReq.Messages)-1].Content,
		Stream:  &openAIReq.Stream,
	}

	if openAIReq.Temperature != 0 {
		temp := float32(openAIReq.Temperature)
		llmReq.Temperature = &temp
	}

	if len(openAIReq.Messages) > 1 {
		llmReq.SystemMsg = &openAIReq.Messages[0].Content
	}

	if len(openAIReq.Messages) > 2 {
		his, err := historyFromMessages(openAIReq.Messages)
		if err != nil {
			return nil, err
		}
		llmReq.History = his
	}

	if openAIReq.MaxTokens != 0 {
		llmReq.MaxTokens = &openAIReq.MaxTokens
	}

	return &llmReq, nil
}

func TransformResponse(req *worker.LlmGenerateFormdataRequestBody, resp *http.Response) (*models.OpenAIResponse, error) {
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var res *worker.LlmResponse
	if err := json.Unmarshal(data, &res); err != nil {
		return nil, err
	}
	openAIResp := &models.OpenAIResponse{
		ID:      GenerateUniqueID(),
		Object:  "chat.completion",
		Created: time.Now().Unix(),
		Model:   *req.ModelId,
		Choices: []models.Choice{
			{
				Index: 0,
				Message: models.Message{
					Role:    "assistant",
					Content: res.Response,
				},
				FinishReason: "stop",
			},
		},
		Usage: models.Usage{
			PromptTokens:     len(req.Prompt), // TODO: count actual tokens
			CompletionTokens: res.TokensUsed,
			TotalTokens:      res.TokensUsed + len(req.Prompt), // Adjust if you have prompt tokens count
		},
	}

	return openAIResp, nil
}

func TransformStreamResponse(chunk worker.LlmStreamChunk, streamID string) (models.OpenAIStreamResponse, error) {
	openAIResp := models.OpenAIStreamResponse{
		ID:      streamID,
		Object:  "text_completion",
		Created: time.Now().Unix(),
		Model:   "gpt-3.5-turbo-0301", // You might want to make this configurable
		Choices: []models.StreamChoice{
			{
				Index: 0,
				Delta: models.Delta{
					Content: chunk.Chunk,
				},
				FinishReason: "",
			},
		},
	}

	if chunk.Done {
		openAIResp.Choices[0].FinishReason = "stop"
	}

	return openAIResp, nil
}

func HandleStreamingResponse(ctx context.Context, resp *http.Response) (<-chan models.OpenAIStreamResponse, <-chan error) {
	streamChan := make(chan models.OpenAIStreamResponse)
	errChan := make(chan error, 1) // Buffered channel to avoid goroutine leak

	go func() {
		defer close(streamChan)
		defer close(errChan)

		streamID := GenerateUniqueID()
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
					openAIChunk, err := TransformStreamResponse(chunk, streamID)
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
				openAIChunk, err := TransformStreamResponse(chunk, streamID)
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

func GenerateUniqueID() string {
	return "chatcmpl-" + uuid.New().String()
}
