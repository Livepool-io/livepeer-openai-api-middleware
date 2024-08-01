package common

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/livepeer/ai-worker/worker"
	"github.com/livepool-io/openai-middleware/models"
)

func historyFromMessages(messages []models.OpenAIMessage) (*string, error) {
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
	his, err := historyFromMessages(openAIReq.Messages)
	if err != nil {
		return nil, err
	}
	llmReq := worker.LlmGenerateFormdataRequestBody{
		Prompt:    openAIReq.Messages[len(openAIReq.Messages)-1].Content,
		History:   his,
		SystemMsg: &openAIReq.Messages[0].Content,
		Stream:    &openAIReq.Stream,
		MaxTokens: &openAIReq.MaxTokens,
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

func GenerateUniqueID() string {
	return "chatcmpl-" + uuid.New().String()
}
