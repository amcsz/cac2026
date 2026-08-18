#!/bin/sh
set -e

if [ "${WAIT_FOR_POSTGRES:-0}" = "1" ]; then
  echo "Waiting for postgres at ${POSTGRES_HOST}:${POSTGRES_PORT:-5432}..."
  while ! nc -z "${POSTGRES_HOST}" "${POSTGRES_PORT:-5432}"; do
    sleep 1
  done
fi

python manage.py migrate --noinput

if [ "${SEED_INITIAL_DATA:-0}" = "1" ]; then
  python manage.py seed_initial_data
fi

exec "$@"
