package middleware

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/golang/glog"
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
	// TODO: on gateway creation fetch from gateway and store
	// then return them here
	// TODO: then we can also add a check that the gateway has the capabilities
	return g.defaultModels
}

func (g *Gateway) PostLlmGenerate(req worker.GenLLMFormdataRequestBody) (*http.Response, error) {
	var body bytes.Buffer
	mw, err := worker.NewLLMMultipartWriter(&body, req)
	if err != nil {
		return nil, err
	}
	defer mw.Close()
	httpReq, err := http.NewRequest("POST", g.url+"/llm-generate", &body)
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", mw.FormDataContentType())
	client := &http.Client{}
	return client.Do(httpReq)
}

func (g *Gateway) HandleStreamingResponse(ctx context.Context, req *worker.BodyGenLLM, w http.ResponseWriter, resp *http.Response) error {
	streamChan, errChan := common.HandleStreamingResponse(ctx, req, resp)

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
