#!/bin/bash
set -e
redis-server --daemonize yes
exec python3 app.py
