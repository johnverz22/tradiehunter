# Fixo dev shortcuts — run from the repo root.
# Requires: Docker (OrbStack), Flutter on host.
#
#   make              → docker up (no rebuild) + Flutter on Android
#   make ios          → docker up + Flutter on iOS
#   make web          → docker up + Flutter on Chrome
#   make docker       → docker services only
#   make build        → force-rebuild Docker images + Flutter on Android
#   make stop         → docker compose down
#   make logs         → tail all container logs
#   make migrate      → run EF Core migrations inside api container

.PHONY: all android ios web docker build stop logs migrate

all: android

android:
	@./dev.sh android

ios:
	@./dev.sh ios

web:
	@./dev.sh web

docker:
	@./dev.sh docker

build:
	@./dev.sh android --build

stop:
	@./dev.sh stop

logs:
	docker compose logs -f

migrate:
	docker compose run --rm --entrypoint /bin/bash api -c "dotnet restore && dotnet ef database update"
