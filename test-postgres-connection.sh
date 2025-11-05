#!/bin/bash

echo "=== PostgreSQL Connection Test ==="
echo ""

# Test 1: Check if PostgreSQL is running on host
echo "1. Testing if PostgreSQL is listening on port 5432..."
if command -v nc &> /dev/null; then
    nc -zv localhost 5432 2>&1 | grep -q succeeded && echo "✓ PostgreSQL is listening on localhost:5432" || echo "✗ PostgreSQL is NOT listening on localhost:5432"
else
    echo "⚠ netcat not installed, skipping port check"
fi
echo ""

# Test 2: Check PostgreSQL status
echo "2. Checking PostgreSQL service status..."
if command -v systemctl &> /dev/null; then
    systemctl is-active postgresql 2>&1
else
    echo "⚠ systemctl not available"
fi
echo ""

# Test 3: Test connection with psql
echo "3. Testing connection with psql..."
if command -v psql &> /dev/null; then
    PGPASSWORD='E1uLlt7tDeJLZx4J88BgYfeTi2aHzo+Q69DN1c+30S8=' psql -h localhost -U bagetter_user -d bagetter_stable -c "SELECT 'Connection successful!' as status;" 2>&1
else
    echo "⚠ psql not installed"
fi
echo ""

# Test 4: Check if PostgreSQL allows connections from Docker
echo "4. Checking PostgreSQL configuration for Docker connections..."
if [ -f /etc/postgresql/*/main/postgresql.conf ]; then
    echo "listen_addresses setting:"
    grep -r "listen_addresses" /etc/postgresql/*/main/postgresql.conf 2>/dev/null || echo "Not found in default location"
    echo ""
    echo "pg_hba.conf entries:"
    cat /etc/postgresql/*/main/pg_hba.conf 2>/dev/null | grep -v "^#" | grep -v "^$" || echo "Not found in default location"
else
    echo "⚠ PostgreSQL config not in default location"
fi
echo ""

# Test 5: Docker network test
echo "5. Running Docker connection test..."
echo "This will test connections from a Docker container..."
docker run --rm \
    --add-host=host.docker.internal:host-gateway \
    postgres:15-alpine \
    sh -c "
    apk add --no-cache postgresql-client >/dev/null 2>&1 &&
    echo 'Testing host.docker.internal...' &&
    pg_isready -h host.docker.internal -p 5432 -U bagetter_user -d bagetter_stable 2>&1 &&
    echo 'Testing 172.17.0.1...' &&
    pg_isready -h 172.17.0.1 -p 5432 -U bagetter_user -d bagetter_stable 2>&1
    " 2>&1

echo ""
echo "=== Test Complete ==="
echo ""
echo "If connections are failing, check:"
echo "1. PostgreSQL is running: sudo systemctl status postgresql"
echo "2. PostgreSQL is listening on all interfaces: listen_addresses = '*' in postgresql.conf"
echo "3. Firewall allows connections: sudo ufw allow 5432/tcp"
echo "4. pg_hba.conf allows connections from Docker network (172.17.0.0/16)"
