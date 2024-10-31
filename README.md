# Livepeer OpenAI API middleware

This project provides middleware that mimics the OpenAI API for the Livepeer AI gateway. This allows developers to use Livepeer AI gateways using the `openai` library, creating a developer experience AI application developers are accustomed with.

#### As HTTP Server

The program runs an HTTP server connected to a _Livepeer AI gateway_. It takes user requests in OpenAI format, forwards them to the specified Livepeer AI Gateway, and returns the response in OpenAI format to the caller.

#### As Package

The `common` package exposes helpers that help you transform between OpenAI and and Livepeer's AI Worker types.

- `func TransformRequest(openAIReq models.OpenAIRequest) (*worker.LlmGenerateFormdataRequestBody, error)`
- `TransformResponse(req *worker.LlmGenerateFormdataRequestBody, resp *http.Response) (*models.OpenAIResponse, error)`
- `func TransformStreamResponse(chunk worker.LlmStreamChunk, streamID string) (models.OpenAIStreamResponse, error)`

It also exports a function for you to easily handle streaming responses and receive them in OpenAI format on a channel, for you to handle as you see fit. _The server mode returns them over SSE, but websockets or other transport methods can also be used_

- `func HandleStreamingResponse(ctx context.Context, resp *http.Response) (<-chan models.OpenAIStreamResponse, <-chan error)`

## Intended Usage

```ts
import OpenAI from "openai"

const oai = new OpenAI({
    baseURL: "<MIDDLEWARE_SERVER>",
})

try {
    const res = await oai.chat.completions.create({
        messages: [
            {
                role: "user",
                content: "Tell me more about the Livepeer network"
            }
        ],
        model: "meta-llama/Llama-3.1-8B-Instruct"
        stream: true
    })

    // log the reply
    console.log(res.choices[0].message.content)
} catch(err) {
    console.log(err)
}
```

## Current features

- Forward LLM chat completion requests to a gateway using the LLM Pipeline.
- Stream support for LLM requests using server-sent-events (SSE).

## Planned features

- Forward other completion requests for other types of pipelines/models

## Requirements

- Go 1.21.x
- Docker (optional)

## Getting Started

### Clone the Repository

```sh
git clone https://github.com/livepool-io/livepeer-openai-api-middleware.git
```

Run the server

```sh
go openai-api -gateway <LIVEPEER_GATEWAY>
```

### Build from source

1. Install dependencies

    ```sh
    go mod download
    ```

2. Build binary

    ```sh
    go build openai-api.go
    ```

3. Run the program

```sh
./openai-api -gateway <LIVEPEER_GATEWAY>
```

### Using Docker

1. Build container

    ```sh
    docker build -t openai-api .
    ```

2. Run container

    ```sh
    docker run -p 8080:8080 openai-api -gateway <LIVEPEER_GATEWAY>
    ```

## Request & Response types

The main difference between _OpenAI_ and the _Livepeer Gateway_ is that the Livepeer Gateway currenetly follows a schema similar to what _Llama_ models would expect.

_OpenAI_ uses `messages` for both the current prompt and the chat history, while the gateway has a separete field for the current prompt and the previous history.

The first message in the `messages` array would be equivalent to the system message.

The response is also different, where with _OpenAI_ it's a stringified JSON object, while the gateway returns the string directly.

### OpenAI

#### Request

```go
type OpenAIRequest struct {
 Model            string          `json:"model"`
 Messages         []OpenAIMessage `json:"messages"`
 MaxTokens        int             `json:"max_tokens,omitempty"`
 Temperature      float64         `json:"temperature,omitempty"`
 TopP             float64         `json:"top_p,omitempty"`
 N                int             `json:"n,omitempty"`
 Stop             []string        `json:"stop,omitempty"`
 PresencePenalty  float64         `json:"presence_penalty,omitempty"`
 FrequencyPenalty float64         `json:"frequency_penalty,omitempty"`
 User             string          `json:"user,omitempty"`
 Stream           bool            `json:"stream,omitempty"`
}
```

#### Response (stream and non-stream)

```go
type OpenAIResponse struct {
 ID      string   `json:"id"`
 Object  string   `json:"object"`
 Created int64    `json:"created"`
 Model   string   `json:"model"`
 Choices []Choice `json:"choices"`
 Usage   Usage    `json:"usage"`
}

type OpenAIStreamResponse struct {
 ID      string         `json:"id"`
 Object  string         `json:"object"`
 Created int64          `json:"created"`
 Model   string         `json:"model"`
 Choices []StreamChoice `json:"choices"`
}
```

### Livepeer Gateway

#### Request

```go
type BodyLlmGenerateLlmGeneratePost struct {
 History     *string  `json:"history,omitempty"`
 MaxTokens   *int     `json:"max_tokens,omitempty"`
 ModelId     *string  `json:"model_id,omitempty"`
 Prompt      string   `json:"prompt"`
 Stream      *bool    `json:"stream,omitempty"`
 SystemMsg   *string  `json:"system_msg,omitempty"`
 Temperature *float32 `json:"temperature,omitempty"`
}
```

#### Response (stream and non-stream)

```go
type LlmResponse struct {
 Response   string `json:"response"`
 TokensUsed int    `json:"tokens_used"`
}

type LlmStreamChunk struct {
 Chunk      string `json:"chunk,omitempty"`
 TokensUsed int    `json:"tokens_used,omitempty"`
 Done       bool   `json:"done,omitempty"`
}
```

## Prisma & Postgres

1. Install the auto-generated query builder for go

```sh
go get github.com/steebchen/prisma-client-go
```

To generate the schema from an existing database, specify the DB source in our `schema.prisma` file and pull the schema

```sh
go run github.com/steebchen/prisma-client-go db pull
```

Once we have our schema we can generate our client bindings:

```sh
make db
```
