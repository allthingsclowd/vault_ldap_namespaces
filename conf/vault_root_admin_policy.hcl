## Operations

# Manage namespaces
path "sys/namespaces/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List audit backends
path "sys/audit" {
  capabilities = ["read","list"]
}

# Create an audit backend. Operators are not allowed to remove them.
path "sys/audit/*" {
  capabilities = ["create","read","list","sudo"]
}

# List Authentication Backends
path "sys/auth" {
  capabilities = ["read","list"]
}

# CRUD operations on Authentication Backends
path "sys/auth/*" {
  capabilities = ["read","list","update","sudo"]
}

# CORS configuration
path "sys/config/cors" {
  capabilities = ["read", "list", "create", "update", "sudo"]
}

# Start root token generation
path "sys/generate-root/attempt" {
  capabilities = ["read", "list", "create", "update", "delete"]
}
# Configure License
path "sys/license" {
  capabilities = ["read", "list", "create", "update", "delete"]
}

# Get Storage Key Status
path "sys/key-status" {
  capabilities = ["read"]
}

# Initialize Vault
path "sys/init" {
  capabilities = ["read", "update", "create"]
}

#Get Cluster Leader
path "sys/leader" {
  capabilities = ["read"]
}

# Manage policies
path "sys/policies*" {
  capabilities = ["read", "list", "create", "update", "delete"]
}

# Manage Mounts
path "sys/mounts*" {
  capabilities = ["read", "list", "create", "update", "delete"]
}

# Manage tokens
path "auth/token/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage tokens
path "auth/mydemoldapserver/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}