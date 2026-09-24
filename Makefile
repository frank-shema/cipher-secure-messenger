# Cipher — developer entry points. Run `make help` to list targets.
SHELL := /bin/bash
COMPOSE := $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")
SIMULATOR ?= iPhone 17
XCODE_PROJECT := ios/Cipher.xcodeproj
XCODE_SCHEME := Cipher
XCODE_DEST := platform=iOS Simulator,name=$(SIMULATOR)
API ?= http://localhost:8080

.DEFAULT_GOAL := help

.PHONY: help up down logs restart test test-backend test-ios seed ios-generate ios-open ios-build lint clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

up: ## Start PostgreSQL + relay (dev profile, seeds alice/bob/echo)
	$(COMPOSE) up -d --build
	@echo "Relay:      $(API)"
	@echo "Swagger UI: $(API)/swagger-ui.html"
	@echo "Health:     $(API)/actuator/health"

down: ## Stop everything (keeps volumes)
	$(COMPOSE) down

restart: ## Rebuild and restart the relay only
	$(COMPOSE) up -d --build backend

logs: ## Tail relay logs
	$(COMPOSE) logs -f backend

test: test-backend test-ios ## Run every test suite

test-backend: ## Backend unit + slice + Testcontainers integration tests
	cd backend && mvn -B -ntp verify

test-ios: ## iOS package tests (macOS host) + app tests (simulator)
	cd ios/Packages/CipherCore && swift test
	cd ios/Packages/CipherCrypto && swift test
	xcodebuild -project $(XCODE_PROJECT) -scheme $(XCODE_SCHEME) -destination '$(XCODE_DEST)' -quiet test CODE_SIGNING_ALLOWED=NO

ios-build: ## Build the app for the simulator
	xcodebuild -project $(XCODE_PROJECT) -scheme $(XCODE_SCHEME) -destination '$(XCODE_DEST)' -quiet build CODE_SIGNING_ALLOWED=NO

ios-generate: ## Regenerate Cipher.xcodeproj from ios/project.yml (requires xcodegen)
	cd ios && xcodegen generate

ios-open: ios-generate ## Regenerate and open the Xcode project
	open $(XCODE_PROJECT)

seed: ## Verify the dev seed and print demo credentials (seeding runs automatically under the dev profile)
	@echo "Waiting for relay health..."
	@for i in $$(seq 1 30); do curl -sf $(API)/actuator/health >/dev/null && break || sleep 2; done
	@curl -sf -X POST $(API)/api/v1/auth/login -H 'Content-Type: application/json' -d '{"username":"alice","password":"cipher-alice"}' >/dev/null && echo "Seed OK: demo users are present" || echo "Seed check failed: is the relay running with SPRING_PROFILES_ACTIVE=dev?"
	@echo ""
	@echo "  username  password        role"
	@echo "  alice     cipher-alice    demo user (simulator 1)"
	@echo "  bob       cipher-bob      demo user (simulator 2)"
	@echo "  echo      cipher-echo     demo companion bot (driven by the app's DEBUG-only DemoBot)"

lint: ## SwiftLint (strict) for the iOS code
	cd ios && swiftlint --strict

clean: ## Remove build outputs
	cd backend && mvn -q clean
	rm -rf ios/Packages/*/.build
