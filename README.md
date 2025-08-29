# Hardhat Tasks

## Prerequisites
- Add Concero Router address to environment variables

## Add new chain process
1. [ ] (L2) Deploy USDC.e to a new chain
```bash
yarn hardhat deploy-fiat-token --implementation --proxy --network <network_name>
```
2. [ ] (L2) Deploy LancaCanonicalBridge to a new network
```bash
yarn hardhat deploy-bridge --implementation --proxy --network <network_name>
```
3. [ ] (L1) Deploy pool for new network and add pool to L1
```bash
yarn hardhat deploy-pool --implementation --proxy --dstchain <chain_name> --network <network_name>
```

Ready, transactions can be sent
```bash
yarn hardhat send-token --from <source_network> --to <destination_network> --amount <amount>
```

## Available Tasks

### Bridge Deployment
Deploy LancaCanonicalBridge contracts with flexible options.

```bash
yarn hardhat deploy-bridge [--implementation] [--proxy] [--pause] [--owner <address>] --network <network_name>
```

**Flags:**
- `--implementation` - Deploy implementation
- `--proxy` - Deploy proxy and proxy admin
- `--pause` - Pause bridge

**Parameters:**
- `--owner` - Custom proxy admin owner address (optional)

**Examples:**
```bash
# Deploy implementation only
yarn hardhat deploy-bridge --implementation --network base

# Deploy proxy and admin only
yarn hardhat deploy-bridge --proxy --network base

# Deploy implementation + proxy (with automatic upgrade)
yarn hardhat deploy-bridge --implementation --proxy --network base

# Pause bridge
yarn hardhat deploy-bridge --pause --network base
```

### Pool Deployment
Deploy LancaCanonicalBridgePool contracts with proxy setup and pool configuration.

```bash
yarn hardhat deploy-pool [--implementation] [--proxy] [--pause] [--owner <address>] --dstchain <chain_name> --network <network_name>
```

**Flags:**
- `--implementation` - Deploy pool implementation
- `--proxy` - Deploy proxy and proxy admin for pool
- `--pause` - Pause pool

**Parameters:**
- `--dstchain` - Destination chain name for the pool (required)
- `--owner` - Custom proxy admin owner address (optional)

**Examples:**
```bash
# Deploy pool implementation only
yarn hardhat deploy-pool --implementation --dstchain base --network ethereum

# Deploy proxy and admin only
yarn hardhat deploy-pool --proxy --dstchain base --network ethereum

# Deploy implementation + proxy with automatic upgrade
yarn hardhat deploy-pool --implementation --proxy --dstchain base --network ethereum

# Deploy complete setup and add pool to L1 Bridge
yarn hardhat deploy-pool --implementation --proxy --dstchain base --network ethereum

# Pause pool
yarn hardhat deploy-pool --pause --dstchain base --network ethereum
```

### Fiat Token Deployment
Deploy USDC-compatible FiatToken contracts.

```bash
yarn hardhat deploy-fiat-token [--implementation] [--proxy] --network <network_name>
```

**Flags:**
- `--implementation` - Deploy implementation
- `--proxy` - Deploy proxy

**Examples:**
```bash
# Deploy implementation only
yarn hardhat deploy-fiat-token --implementation --network arbitrum

# Deploy complete setup with configuration
yarn hardhat deploy-fiat-token --implementation --proxy --network arbitrum
```

### Configure Fiat Token

```bash
yarn hardhat configure-minter --network <network_name>
```

### Get Rate Information
Get current rate limit information for bridges.

```bash
yarn hardhat get-rate-info [--dstchain <chain_name>] --network <network_name>
```

**Examples:**
```bash
# Get rate info for L1 bridge
yarn hardhat get-rate-info --dstchain base --network ethereum

# Get rate info for L2 bridge
yarn hardhat get-rate-info --network baseSepolia
```

### Add Destination Bridge
Add destination bridge to LancaCanonicalBridgeL1 contract.

```bash
yarn hardhat add-dst-pool --dstchain <destination_chain_name>
```

**Parameters:**
- `--dstchain` - Destination chain name for the bridge (required)

**Examples:**
```bash
# Add destination bridge for Arbitrum chain
yarn hardhat add-dst-bridge --dstchain arbitrum
```

### Add Destination Pool
Add destination pool to LancaCanonicalBridgeL1 contract.

```bash
yarn hardhat add-dst-pool --dstchain <destination_chain_name>
```
**Parameters:**
- `--dstchain` - Destination chain name for the pool (required)

**Examples:**
```bash
# Add destination pool for Arbitrum chain
yarn hardhat add-dst-pool --dstchain arbitrum
```

### Remove Destination Bridge
Remove destination bridge from LancaCanonicalBridgeL1 contract.

```bash
yarn hardhat remove-dst-bridge --dstchain <destination_chain_name>
```

**Examples:**
```bash
# Remove destination bridge for Arbitrum chain
yarn hardhat remove-dst-bridge --dstchain arbitrum
```

### Remove Destination Pool
Remove destination pool from LancaCanonicalBridgeL1 contract.

```bash
yarn hardhat remove-dst-pool --dstchain <destination_chain_name>
```

**Examples:**
```bash
# Remove destination pool for Arbitrum chain
yarn hardhat remove-dst-pool --dstchain arbitrum
```

### Send Tokens
Send tokens from one chain to another through the Lanca Canonical Bridge.

```bash
yarn hardhat send-token --from <source_network> --to <destination_network> --amount <amount>
```

**Parameters:**
- `--from` - Source network name (e.g., 'arbitrumSepolia', 'baseSepolia')
- `--to` - Destination network name (e.g., 'arbitrumSepolia', 'baseSepolia')
- `--amount` - Amount of USDC to send (e.g., '10.5')

**Examples:**
```bash
# Send 5 USDC from Arbitrum Sepolia to Base Sepolia
yarn hardhat send-token --from arbitrumSepolia --to baseSepolia --amount 5
```

### Set Rate Limits
Set rate limits for LancaCanonicalBridge contracts (both L1 and L2).

```bash
yarn hardhat set-rate-limits [--dstchain <chain_name>] [--outmax <amount>] [--outrefill <speed>] [--inmax <amount>] [--inrefill <speed>] --network <network_name>
```

**Parameters:**
- `--dstchain` - Destination chain name (required for L1 bridge, omit for L2 bridge)
- `--outmax` - Maximum outbound rate amount (in USDC)
- `--outrefill` - Outbound refill speed (USDC per second)
- `--inmax` - Maximum inbound rate amount (in USDC)
- `--inrefill` - Inbound refill speed (USDC per second)

**Examples:**
```bash
# Set rate limits for L1 bridge (with destination chain name)
yarn hardhat set-rate-limits --dstchain base --outmax 1000000 --outrefill 10 --inmax 1000000 --inrefill 10 --network ethereum

# Set rate limits for L2 bridge (without destination chain name)
yarn hardhat set-rate-limits --outmax 500000 --outrefill 5 --inmax 500000 --inrefill 5 --network baseSepolia

# Set only outbound rate limits
yarn hardhat set-rate-limits --dstchain arbitrum --outmax 250000 --outrefill 2 --network ethereum

# Set only inbound rate limits for L2
yarn hardhat set-rate-limits --inmax 100000 --inrefill 1 --network arbitrumSepolia
```

### ProxyAdmin Owner Management
Deploy proxy admins with custom owners and change ownership of existing proxy admins.

```bash
# Deploy with custom owner
yarn hardhat deploy-bridge --proxy --owner <address> --network <network>
yarn hardhat deploy-pool --proxy --owner <address> --dstchain <dst_chain>

# Change existing proxy admin owner
yarn hardhat change-proxy-admin-owner --type <bridge|pool> --newowner <address> [--dstchain <chain_name>] --network <network_name>
```

**Parameters:**
- `--type` - ProxyAdmin type (`bridge`, `pool`)
- `--newowner` - New owner address
- `--dstchain` - Destination chain name (required for pool type)
- `--owner` - Custom owner address for deployment

**Examples:**
```bash
# Deploy bridge proxy with custom owner
yarn hardhat deploy-bridge --proxy --owner 0x1234567890123456789012345678901234567890 --network ethereum

# Deploy pool proxy with custom owner
yarn hardhat deploy-pool --proxy --owner 0x1234567890123456789012345678901234567890 --dstchain base --network ethereum

# Change bridge proxy admin owner
yarn hardhat change-proxy-admin-owner --type bridge --newowner 0x5678901234567890123456789012345678901234 --network ethereum

# Change pool proxy admin owner
yarn hardhat change-proxy-admin-owner --type pool --newowner 0x5678901234567890123456789012345678901234 --dstchain base --network ethereum
```

### Fiat Token Admin Management
Manage FiatToken admin and ownership.

```bash
# Change FiatToken admin
yarn hardhat fiat-token-change-admin --admin <address> --network <network_name>

# Transfer FiatToken ownership
yarn hardhat fiat-token-transfer-ownership --owner <address> --network <network_name>
```

**Examples:**
```bash
# Change admin
yarn hardhat fiat-token-change-admin --admin 0x1234567890123456789012345678901234567890 --network base

# Transfer ownership
yarn hardhat fiat-token-transfer-ownership --owner 0x5678901234567890123456789012345678901234 --network base
```

### Deploy Pause Contracts
Deploy pause contracts for emergency situations.

```bash
# Deploy pause contract to single network
yarn hardhat deploy-pause --network <network_name>

# Deploy pause contracts to all testnet networks
yarn hardhat deploy-concero-pause-to-all-chains
```

**Examples:**
```bash
# Deploy to single network
yarn hardhat deploy-pause --network base

# Deploy to all testnets
yarn hardhat deploy-concero-pause-to-all-chains
```

### Bulk Update Operations
Update multiple contract implementations across networks.

```bash
# Update all bridge implementations
yarn hardhat update-all-bridge-implementations --l1chain <l1_chain_name>

# Update all pool implementations
yarn hardhat update-all-pool-implementations --l1chain <l1_chain_name>
```

**Examples:**
```bash
# Update all bridges
yarn hardhat update-all-bridge-implementations --l1chain ethereum

# Update all pools
yarn hardhat update-all-pool-implementations --l1chain ethereum
```

## Environment Setup

Make sure to configure your environment variables:
- Set `CONCERO_ROUTER_PROXY_<NETWORK_NAME>` for each network

## Contract Addresses

After deployment, addresses are saved to environment variables:
- `LANCA_CANONICAL_BRIDGE_<NETWORK_NAME>` - Implementation address
- `LANCA_CANONICAL_BRIDGE_PROXY_<NETWORK_NAME>` - Proxy address
- `LANCA_CANONICAL_BRIDGE_PROXY_ADMIN_<NETWORK_NAME>` - Proxy admin address

- `LC_BRIDGE_POOL_<NETWORK_NAME>_<NETWORK_NAME>` - Pool implementation address
- `LC_BRIDGE_POOL_PROXY_<NETWORK_NAME>_<NETWORK_NAME>` - Pool proxy address
- `LC_BRIDGE_POOL_PROXY_ADMIN_<NETWORK_NAME>_<NETWORK_NAME>` - Pool proxy admin address

- `FIAT_TOKEN_<NETWORK_NAME>` - FiatToken implementation address
- `FIAT_TOKEN_PROXY_<NETWORK_NAME>` - FiatToken proxy address
- `FIAT_TOKEN_PROXY_ADMIN_<NETWORK_NAME>` - FiatToken proxy admin address 