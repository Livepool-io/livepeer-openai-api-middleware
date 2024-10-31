//go:generate go run github.com/steebchen/prisma-client-go generate

package db

import (
	"context"
	"errors"
	"time"
)

type APIKeyStore struct {
	client *PrismaClient
}

func NewAPIKeyStore() (*APIKeyStore, error) {
	client := NewClient()
	if err := client.Prisma.Connect(); err != nil {
		return nil, err
	}

	return &APIKeyStore{
		client: client,
	}, nil
}

func (s *APIKeyStore) ValidateAndGetAPIKey(ctx context.Context, apiKey string) (*APIKeyModel, error) {
	key, err := s.client.APIKey.FindFirst(
		APIKey.Key.Equals(apiKey),
		APIKey.IsActive.Equals(true),
	).With(
		APIKey.User.Fetch(),
	).Exec(ctx)

	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil, errors.New("invalid API key")
		}
		return nil, err
	}

	return key, nil
}

func (s *APIKeyStore) RecordAPIUsage(ctx context.Context, apiKeyID string, userID string, tokens int) error {
	now := time.Now()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	// First get current usage (outside transaction)
	user, err := s.client.User.FindUnique(
		User.ID.Equals(userID),
	).Exec(ctx)
	if err != nil {
		return err
	}

	// Calculate new usage values
	dailyUsage := user.DailyTokenUsage
	if user.UsageResetAt.Before(startOfDay) {
		dailyUsage = 0
	}

	// Create transaction for updates
	updateUserQuery := s.client.User.FindUnique(
		User.ID.Equals(userID),
	).Update(
		User.DailyTokenUsage.Set(dailyUsage+tokens),
		User.UsageResetAt.Set(now),
	).Tx()

	updateAPIKeyQuery := s.client.APIKey.FindUnique(
		APIKey.ID.Equals(apiKeyID),
	).Update(
		APIKey.DailyTokenUsage.Set(tokens),
		APIKey.UsageResetAt.Set(now),
		APIKey.LastUsedAt.Set(now),
	).Tx()

	upsertUsageQuery := s.client.DailyUsage.UpsertOne(
		DailyUsage.DateUserIDAPIKeyID(
			DailyUsage.Date.Equals(startOfDay),
			DailyUsage.UserID.Equals(userID),
			DailyUsage.APIKeyID.Equals(apiKeyID)),
	).Create(
		DailyUsage.Date.Set(startOfDay),
		DailyUsage.User.Link(User.ID.Equals(userID)),
		DailyUsage.APIKeyID.Set(apiKeyID),
		DailyUsage.TokenUsage.Set(tokens),
	).Update(
		DailyUsage.TokenUsage.Increment(tokens),
	).Tx()

	// Execute transaction for updates only
	err = s.client.Prisma.TX.Transaction(
		updateUserQuery,
		updateAPIKeyQuery,
		upsertUsageQuery,
	).Exec(ctx)

	return err
}

func (s *APIKeyStore) GetUserForAPIKey(ctx context.Context, apiKey string) (*UserModel, error) {
	user, err := s.client.User.FindFirst(
		User.APIKey.Some(
			APIKey.Key.Equals(apiKey),
		),
	).Exec(ctx)

	if err != nil {
		return nil, err
	}

	return user, nil
}

func (s *APIKeyStore) CheckUsageLimit(ctx context.Context, userID string, tokens int) (bool, error) {
	user, err := s.client.User.FindUnique(
		User.ID.Equals(userID),
	).Exec(ctx)

	if err != nil {
		return false, err
	}

	now := time.Now()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	// Reset daily usage if it's a new day
	dailyUsage := user.DailyTokenUsage
	if user.UsageResetAt.Before(startOfDay) {
		dailyUsage = 0
	}

	// Get limit based on user tier
	var limit int
	switch user.Tier {
	case UserTierFree:
		limit = 10000
	case UserTierPro:
		limit = 100000
	case UserTierEnterprise:
		limit = 1000000
	}

	return (dailyUsage + tokens) <= limit, nil
}
