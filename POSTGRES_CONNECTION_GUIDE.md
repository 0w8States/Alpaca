# PostgreSQL Docker Connection Testing Guide

## Quick Test

Run the test script:
```bash
chmod +x test-postgres-connection.sh
./test-postgres-connection.sh
```

Or use the Docker Compose test:
```bash
# Test connection to host PostgreSQL
docker-compose -f docker-compose.test.yml up postgres-host-test

# Test with containerized PostgreSQL (reference)
docker-compose -f docker-compose.test.yml up postgres-container postgres-container-test
```

## Common Issues & Solutions

### Issue 1: Connection Timeout (Your Current Error)

**Symptoms:**
```
Failed to connect to 172.17.0.1:5432
System.TimeoutException: The operation has timed out.
```

**Causes & Solutions:**

#### 1a. PostgreSQL not listening on all interfaces

Check current setting:
```bash
sudo grep listen_addresses /etc/postgresql/*/main/postgresql.conf
```

Fix:
```bash
# Edit postgresql.conf
sudo nano /etc/postgresql/15/main/postgresql.conf

# Change:
# listen_addresses = 'localhost'
# To:
listen_addresses = '*'

# Restart PostgreSQL
sudo systemctl restart postgresql
```

#### 1b. Firewall blocking Docker network

```bash
# Check if firewall is active
sudo ufw status

# Allow PostgreSQL port
sudo ufw allow 5432/tcp

# Or for Docker network only
sudo ufw allow from 172.17.0.0/16 to any port 5432
```

#### 1c. pg_hba.conf not allowing Docker connections

Check current settings:
```bash
sudo cat /etc/postgresql/*/main/pg_hba.conf
```

Add this line to allow Docker network:
```bash
sudo nano /etc/postgresql/*//main/pg_hba.conf

# Add this line (before any "reject" rules):
host    all             all             172.17.0.0/16           scram-sha-256
```

Reload configuration:
```bash
sudo systemctl reload postgresql
```

### Issue 2: Wrong Host Address

Docker containers need special addresses to reach the host:

- **Docker Desktop (Mac/Windows)**: Use `host.docker.internal`
- **Linux**: Use `172.17.0.1` (default bridge) or find gateway:
  ```bash
  docker network inspect bridge | grep Gateway
  ```

### Issue 3: Database/User doesn't exist

Create them:
```bash
sudo -u postgres psql << EOF
CREATE DATABASE bagetter_stable;
CREATE USER bagetter_user WITH PASSWORD 'E1uLlt7tDeJLZx4J88BgYfeTi2aHzo+Q69DN1c+30S8=';
GRANT ALL PRIVILEGES ON DATABASE bagetter_stable TO bagetter_user;
EOF
```

## Recommended Connection Strings

### For Linux Docker Host:
```
Host=172.17.0.1;Database=bagetter_stable;Username=bagetter_user;Password=E1uLlt7tDeJLZx4J88BgYfeTi2aHzo+Q69DN1c+30S8=;Port=5432
```

### For Docker Desktop (Mac/Windows):
```
Host=host.docker.internal;Database=bagetter_stable;Username=bagetter_user;Password=E1uLlt7tDeJLZx4J88BgYfeTi2aHzo+Q69DN1c+30S8=;Port=5432
```

### Alternative: Run PostgreSQL in Docker

Create a `docker-compose.yml`:
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: bagetter_stable
      POSTGRES_USER: bagetter_user
      POSTGRES_PASSWORD: E1uLlt7tDeJLZx4J88BgYfeTi2aHzo+Q69DN1c+30S8=
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  bagetter:
    image: your-bagetter-image
    depends_on:
      - postgres
    environment:
      Database__Type: PostgreSql
      Database__ConnectionString: "Host=postgres;Database=bagetter_stable;Username=bagetter_user;Password=E1uLlt7tDeJLZx4J88BgYfeTi2aHzo+Q69DN1c+30S8="

volumes:
  pgdata:
```

Connection string when both in same Docker network:
```
Host=postgres;Database=bagetter_stable;Username=bagetter_user;Password=E1uLlt7tDeJLZx4J88BgYfeTi2aHzo+Q69DN1c+30S8=
```

## Verification Steps

1. **Check PostgreSQL is running:**
   ```bash
   sudo systemctl status postgresql
   ```

2. **Test local connection:**
   ```bash
   PGPASSWORD='E1uLlt7tDeJLZx4J88BgYfeTi2aHzo+Q69DN1c+30S8=' \
   psql -h localhost -U bagetter_user -d bagetter_stable -c "SELECT 1;"
   ```

3. **Test from Docker:**
   ```bash
   docker run --rm --add-host=host.docker.internal:host-gateway postgres:15-alpine \
   pg_isready -h host.docker.internal -p 5432 -U bagetter_user -d bagetter_stable
   ```

4. **Check PostgreSQL logs:**
   ```bash
   sudo tail -f /var/log/postgresql/postgresql-*-main.log
   ```
