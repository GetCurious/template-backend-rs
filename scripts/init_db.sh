#!/usr/bin/env bash
set -x
set -eo pipefail

# Check if a custom user has been set, otherwise default to 'postgres'
DB_USER="${POSTGRES_USER:=postgres}"
# Check if a custom password has been set, otherwise default to 'password'
DB_PASSWORD="${POSTGRES_PASSWORD:=password}"
# Check if a custom password has been set, otherwise default to 'newsletter'
DB_NAME="${POSTGRES_DB:=newsletter}"
# Check if a custom port has been set, otherwise default to '5432'
DB_PORT="${POSTGRES_PORT:=5432}"
# Check if a custom host has been set, otherwise default to 'localhost'
DB_HOST="${POSTGRES_HOST:=localhost}"

OLD_POSTGRES_CONTAINER=$(docker ps --filter 'name=postgres' --format '{{.ID}}' -a)
if [[ -n ${OLD_POSTGRES_CONTAINER} ]]; then
  echo >&2 "Removing old postgres container:"
  docker container rm -fv ${OLD_POSTGRES_CONTAINER}
fi

# Launch postgres using Docker
RUNNING_POSTGRES_CONTAINER=$(docker run \
  -d \
  --name postgres \
  -e POSTGRES_USER="${DB_USER}" \
  -e POSTGRES_PASSWORD="${DB_PASSWORD}" \
  -e POSTGRES_DB="${DB_NAME}" \
  -p "${DB_PORT}":5432 \
  postgres \
  -c max_connections=1000)
# ^ Increase postgres max connections for testing purposes

sleep 3

# Keep pinging Postgres until it's ready to accept commands
until docker exec -e PGPASSWORD="${DB_PASSWORD}" "${RUNNING_POSTGRES_CONTAINER}" psql -h "${DB_HOST}" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q'; do
  echo >&2 "Postgres is still unavailable - sleeping"
  sleep 3
done

echo >&2 "Postgres is up and running on port ${DB_PORT} - running migrations now!"

export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
sqlx database create
sqlx migrate run

echo >&2 "Postgres has been migrated, ready to go!"
