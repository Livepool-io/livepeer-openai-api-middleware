// database/supabase.go

package db

import (
	"fmt"

	"github.com/supabase-community/supabase-go"
)

type SupabaseAPIKeyStore struct {
	client *supabase.Client
}

func NewSupabaseAPIKeyStore(supabaseURL, supabaseKey string) (*SupabaseAPIKeyStore, error) {
	client, err := supabase.NewClient(supabaseURL, supabaseKey, nil)
	if err != nil {
		return nil, fmt.Errorf("cannot initialize Supabase client: %w", err)
	}
	return &SupabaseAPIKeyStore{client: client}, nil
}

func (s *SupabaseAPIKeyStore) ValidateAPIKey(apiKey string) (bool, error) {
	_, count, err := s.client.From("api_keys").
		Select("id", "exact", false).
		Eq("key", apiKey).
		Execute()

	if err != nil {
		return false, fmt.Errorf("error checking API key: %w", err)
	}

	return count > 0, nil
}
