#!/bin/bash

# Check if any arguments were provided
if [ $# -eq 0 ]; then
  echo "Running in interactive mode..."
  exec /bin/bash
else
  echo "Running provided command..."
  exec "$@"
fi