# Hardhat Tasks

## Add new chain process
1. [ ] Add Concero Router address to environment variables
2. [ ] (L2) Deploy USDC.e to a new chain
```bash
yarn hardhat deploy-fiat-token [--implementation] [--proxy] --network <network_name>
```
3. [ ] (L2) Deploy LancaCanonicalBridge to a new network
```bash
yarn hardhat deploy-bridge [--implementation] [--proxy] [--pause] --chain <chain_name> --network <network_name>
```
4. [ ] (L2) Configure minter for USDC.e -> LancaCanonicalBridge
```bash
yarn hardhat configure-minter [--bridge] [--test] --network <network_name>
```
5. [ ] (L1) Deploy pool for new network and add pool to L1
```bash
yarn hardhat deploy-pool [--implementation] [--proxy] [--addpool] [--pause] --chain <chain_name> --network <network_name>
```
6. [ ] (L1) Add lane for new network in L1
```bash
yarn hardhat add-lane --chain <destination_chain_name> --network <network_name>
```
7. [ ] (L1) Set rate limits for new network
```bash
yarn hardhat set-rate-limits [--dstchain <chain_name>] [--outmax <amount>] [--outrefill <speed>] [--inmax <amount>] [--inrefill <speed>] --network <network_name>
```
8. [ ] (L1, L2) Ready, transactions can be sent
```bash
yarn hardhat send-token --from <source_network> --to <destination_network> --amount <amount>
```

## Available Tasks

### Bridge Deployment
Deploy LancaCanonicalBridge contracts with flexible options.

```bash
yarn hardhat deploy-bridge [--implementation] [--proxy] [--pause] [--owner <address>] --chain <l1-chain_name> --network <network_name>
```

**Flags:**
- `--implementation` - Deploy implementation
- `--proxy` - Deploy proxy and proxy admin
- `--pause` - Pause bridge

**Parameters:**
- `--chain` - Destination chain name (required) (L1 chain name)
- `--owner` - Custom proxy admin owner address (optional)

**Examples:**
```bash
# Deploy implementation only
yarn hardhat deploy-bridge --implementation --chain ethereum --network base

# Deploy proxy and admin only
yarn hardhat deploy-bridge --proxy --chain ethereum --network base

# Deploy implementation + proxy (with automatic upgrade)
yarn hardhat deploy-bridge --implementation --proxy --chain ethereum --network base

# Pause bridge
yarn hardhat deploy-bridge --pause --chain ethereum --network base
```

### Bridge L1 Deployment
Deploy LancaCanonicalBridge L1 specific components.

```bash
yarn hardhat deploy-bridge-l1 [--implementation] [--proxy] [--pause] [--owner <address>] --network <network_name>
```

**Flags:**
- `--implementation` - Deploy L1 bridge implementation
- `--proxy` - Deploy proxy and proxy admin
- `--pause` - Pause L1 bridge

**Parameters:**
- `--owner` - Custom proxy admin owner address (optional)

**Examples:**
```bash
# Deploy L1 implementation only
yarn hardhat deploy-bridge-l1 --implementation --network ethereum

# Deploy L1 complete setup
yarn hardhat deploy-bridge-l1 --implementation --proxy --network ethereum

# Pause L1 bridge
yarn hardhat deploy-bridge-l1 --pause --network ethereum
```

### Pool Deployment
Deploy LancaCanonicalBridgePool contracts with proxy setup and pool configuration.

```bash
yarn hardhat deploy-pool [--implementation] [--proxy] [--addpool] [--pause] [--owner <address>] --chain <dst_chain_name> --network <network_name>
```

**Flags:**
- `--implementation` - Deploy pool implementation
- `--proxy` - Deploy proxy and proxy admin for pool
- `--addpool` - Add pool to L1 Bridge contract
- `--pause` - Pause pool

**Parameters:**
- `--chain` - Destination chain name for the pool (required)
- `--owner` - Custom proxy admin owner address (optional)

**Examples:**
```bash
# Deploy pool implementation only
yarn hardhat deploy-pool --implementation --chain base --network ethereum

# Deploy proxy and admin only
yarn hardhat deploy-pool --proxy --chain base --network ethereum

# Deploy implementation + proxy with automatic upgrade
yarn hardhat deploy-pool --implementation --proxy --chain base --network ethereum

# Deploy complete setup and add pool to L1 Bridge
yarn hardhat deploy-pool --implementation --proxy --addpool --chain base --network ethereum

# Pause pool
yarn hardhat deploy-pool --pause --chain base --network ethereum
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
yarn hardhat configure-minter [--bridge] [--test] --network <network_name>
```

**Flags:**
- `--bridge` - Configure Minter for bridge
- `--test` - Configure Minter for test

### Add Lane
Add lane to LancaCanonicalBridge contract.

```bash
yarn hardhat add-lane --chain <destination_chain_name> --network <network_name>
```

**Parameters:**
- `--chain` - Destination chain name for the lane (required)

**Examples:**
```bash
# Add lane for Arbitrum chain
yarn hardhat add-lane --chain base --network ethereum
```

### Send Tokens
Send tokens from one chain to another through the Lanca Canonical Bridge.

```bash
yarn hardhat send-token --from <source_network> --to <destination_network> --amount <amount> [--gaslimit <gas_limit>]
```

**Parameters:**
- `--from` - Source network name (e.g., 'arbitrumSepolia', 'baseSepolia')
- `--to` - Destination network name (e.g., 'arbitrumSepolia', 'baseSepolia')
- `--amount` - Amount of USDC to send (e.g., '10.5')
- `--gaslimit` - Gas limit for destination transaction (optional, defaults to 150000)

**Examples:**
```bash
# Send 5 USDC from Arbitrum Sepolia to Base Sepolia (with default gas limit)
yarn hardhat send-token --from arbitrumSepolia --to baseSepolia --amount 5

# Send 100 USDC from Ethereum to Base with custom gas limit
yarn hardhat send-token --from ethereum --to base --amount 100 --gaslimit 200000
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
yarn hardhat deploy-pool --proxy --owner <address> --chain <dst_chain> --network <network>

# Change existing proxy admin owner
yarn hardhat change-proxy-admin-owner --type <bridge|pool> --newowner <address> [--chain <chain>] --network <network>
```

**Parameters:**
- `--type` - ProxyAdmin type (`bridge`, `pool`)
- `--newowner` - New owner address
- `--chain` - Destination chain name (required for pool type)
- `--owner` - Custom owner address for deployment

**Examples:**
```bash
# Deploy bridge proxy with custom owner
yarn hardhat deploy-bridge --proxy --owner 0x1234567890123456789012345678901234567890 --network ethereum

# Deploy pool proxy with custom owner
yarn hardhat deploy-pool --proxy --owner 0x1234567890123456789012345678901234567890 --chain base --network ethereum

# Change bridge proxy admin owner
yarn hardhat change-proxy-admin-owner --type bridge --newowner 0x5678901234567890123456789012345678901234 --network ethereum

# Change pool proxy admin owner
yarn hardhat change-proxy-admin-owner --type pool --newowner 0x5678901234567890123456789012345678901234 --chain base --network ethereum
```

### Mint Test USDC
Mint Test USDC tokens to a specified address.

```bash
yarn hardhat mint-test-usdc --to <recipient_address> --amount <amount> --network <network_name>
```

**Parameters:**
- `--to` - The address to mint USDC to
- `--amount` - The amount of USDC to mint

**Examples:**
```bash
# Mint 1000 USDC to specific address
yarn hardhat mint-test-usdc --to 0x1234567890123456789012345678901234567890 --amount 1000000000 --network arbitrumSepolia
```

## Alternative: Using Hardhat Deploy Tags

You can also use the standard hardhat-deploy plugin:

```bash
# Deploy bridge implementation
yarn hardhat deploy --tags LancaCanonicalBridge --network <network_name>

# Deploy bridge proxy
yarn hardhat deploy --tags LancaCanonicalBridgeProxy --network <network_name>

# Deploy proxy admin
yarn hardhat deploy --tags LancaCanonicalBridgeProxyAdmin --network <network_name>
```

## Environment Setup

Make sure to configure your environment variables:
- Create `.env.usdc` based on `.env.usdc.example`
- Set `CONCERO_ROUTER_PROXY_<NETWORK_NAME>` for each network

## Contract Addresses

After deployment, addresses are saved to environment variables:
- `LANCA_CANONICAL_BRIDGE_<NETWORK_NAME>` - Implementation address
- `LANCA_CANONICAL_BRIDGE_PROXY_<NETWORK_NAME>` - Proxy address
- `LANCA_CANONICAL_BRIDGE_PROXY_ADMIN_<NETWORK_NAME>` - Proxy admin address
- `LANCA_CANONICAL_BRIDGE_POOL_<NETWORK_NAME>` - Pool implementation address
- `LANCA_CANONICAL_BRIDGE_POOL_PROXY_<NETWORK_NAME>` - Pool proxy address
- `LANCA_CANONICAL_BRIDGE_POOL_PROXY_ADMIN_<NETWORK_NAME>` - Pool proxy admin address
- `FIAT_TOKEN_<NETWORK_NAME>` - FiatToken implementation address
- `FIAT_TOKEN_PROXY_<NETWORK_NAME>` - FiatToken proxy address
- `FIAT_TOKEN_PROXY_ADMIN_<NETWORK_NAME>` - FiatToken proxy admin address 