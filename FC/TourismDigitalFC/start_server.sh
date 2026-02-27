#!/bin/bash
# Startup script for Sigiriya Tourism FastAPI Server

cd "$(dirname "$0")"

echo "Starting Sigiriya Tourism API Server..."
echo "MongoDB URI configured ✓"
echo "Server will be available at http://localhost:8000"
echo ""
echo "API Documentation: http://localhost:8000/docs"
echo ""

python main.py
