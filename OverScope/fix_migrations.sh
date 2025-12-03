#!/bin/bash
# Fix schema.rb permissions and run migrations

echo "Fixing schema.rb permissions..."
sudo chown $USER:$USER db/schema.rb 2>/dev/null || echo "Note: You may need to run: sudo chown $USER:$USER db/schema.rb"

echo "Running migrations..."
rails db:migrate

echo "Done!"

