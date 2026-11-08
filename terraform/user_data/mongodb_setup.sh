
#!/bin/bash
set -euo pipefail

# Prevent concurrent bootstrap executions
exec > >(tee -a /var/log/mongodb-bootstrap.log) 2>&1

echo "Starting MongoDB bootstrap..."

# Update system packages
yum update -y

# Install supporting utilities
yum install -y curl openssl awscli

# Configure the official MongoDB 7.0 repository
cat > /etc/yum.repos.d/mongodb-org-7.0.repo <<'EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF

# Install MongoDB
yum install -y mongodb-org mongodb-mongosh

# Retrieve MongoDB credentials from Parameter Store
AWS_REGION="eu-north-1"

MONGO_USERNAME=$(aws ssm get-parameter \
  --name "/startuptech/mongodb/root_username" \
  --region "$AWS_REGION" \
  --query "Parameter.Value" \
  --output text)

MONGO_PASSWORD=$(aws ssm get-parameter \
  --name "/startuptech/mongodb/root_password" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query "Parameter.Value" \
  --output text)
trap 'unset MONGO_PASSWORD MONGO_USERNAME' EXIT
# Obtain private IP through IMDSv2
TOKEN=$(curl -fsS -X PUT \
  "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

PRIVATE_IP=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

PRIVATE_HOSTNAME=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-hostname)

# Configure MongoDB for initial replica-set setup
cat > /etc/mongod.conf <<EOF
storage:
  dbPath: /var/lib/mongo

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 127.0.0.1,${PRIVATE_IP}

replication:
  replSetName: rs0
EOF

# Start MongoDB temporarily without authentication
systemctl enable mongod
systemctl restart mongod

# Wait for MongoDB to become available
MONGO_READY=false

for attempt in $(seq 1 30); do
  if mongosh --quiet --eval "db.adminCommand('ping').ok" | grep -q 1; then
    MONGO_READY=true
    break
  fi
  sleep 5
done

if [ "$MONGO_READY" != "true" ]; then
  echo "ERROR: MongoDB did not become ready."
  exit 1
fi

# Initialize single-node replica set
mongosh --quiet --eval '
try {
  rs.status();
} catch (e) {
  rs.initiate({
    _id: "rs0",
    members: [{ _id: 0, host: "'"${PRIVATE_HOSTNAME}"':27017" }]
  });
}
'

# Wait for the replica set to elect its primary
PRIMARY_READY=false

for attempt in $(seq 1 30); do
  if mongosh --quiet --eval "db.hello().isWritablePrimary" | grep -q true; then
    PRIMARY_READY=true
    break
  fi
  sleep 5
done

if [ "$PRIMARY_READY" != "true" ]; then
  echo "ERROR: MongoDB replica set did not elect a primary."
  exit 1
fi

# Create MongoDB administrator
export MONGO_USERNAME
export MONGO_PASSWORD

mongosh admin --quiet --eval '
const username = process.env.MONGO_USERNAME;
const password = process.env.MONGO_PASSWORD;

if (!db.getUser(username)) {
  db.createUser({
    user: username,
    pwd: password,
    roles: [{ role: "root", db: "admin" }]
  });
}
'

# Generate MongoDB internal authentication keyfile
install -d -o mongod -g mongod -m 700 /etc/mongodb

openssl rand -base64 756 > /etc/mongodb/mongodb-keyfile
chown mongod:mongod /etc/mongodb/mongodb-keyfile
chmod 400 /etc/mongodb/mongodb-keyfile

# Enable authorization and internal authentication
cat >> /etc/mongod.conf <<'EOF'

security:
  authorization: enabled
  keyFile: /etc/mongodb/mongodb-keyfile
EOF

# Restart MongoDB with authentication enabled
systemctl restart mongod

# Wait for authenticated MongoDB connection
AUTH_READY=false

for attempt in $(seq 1 30); do
  if mongosh \
    --quiet \
    --host 127.0.0.1 \
    --username "$MONGO_USERNAME" \
    --password "$MONGO_PASSWORD" \
    --authenticationDatabase admin \
    --eval "db.adminCommand('ping').ok" | grep -q 1; then
    AUTH_READY=true
    break
  fi
  sleep 5
done

if [ "$AUTH_READY" != "true" ]; then
  echo "ERROR: Authenticated MongoDB connection failed."
  exit 1
fi

echo "MongoDB authenticated connection verified."
echo "MongoDB bootstrap completed."
