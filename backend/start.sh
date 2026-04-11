#!/bin/bash

echo "Waiting for PostgreSQL to be ready..."
while ! pg_isready -h postgres -p 5432 -U autogo; do
  sleep 1
done

echo "PostgreSQL is ready!"
echo "Starting FastAPI application..."

exec uvicorn main:app --host 0.0.0.0 --port 8000 --reload
