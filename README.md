# Hardhat Tasks

## Available Tasks

### Bridge Deployment
Deploy LancaCanonicalBridge contracts with flexible options.

```bash
yarn hardhat deploy-bridge [--implementation] [--proxy] --chain <chain_name> --network <network_name>
```

**Flags:**
- `--implementation` - Deploy implementation
- `--proxy` - Deploy proxy and proxy admin

**Parameters:**
- `--chain` - Destination chain name (required)

**Examples:**
```bash
# Deploy implementation only
yarn hardhat deploy-bridge --implementation --chain arbitrum --network arbitrum

# Deploy proxy and admin only
yarn hardhat deploy-bridge --proxy --chain arbitrum --network arbitrum

# Deploy implementation + proxy (with automatic upgrade)
yarn hardhat deploy-bridge --implementation --proxy --chain arbitrum --network arbitrum
```

### Bridge L1 Deployment
Deploy LancaCanonicalBridge L1 specific components.

```bash
yarn hardhat deploy-bridge-l1 [--implementation] [--proxy] --network <network_name>
```

**Flags:**
- `--implementation` - Deploy L1 bridge implementation
- `--proxy` - Deploy proxy and proxy admin

**Examples:**
```bash
# Deploy L1 implementation only
yarn hardhat deploy-bridge-l1 --implementation --network ethereum

# Deploy L1 complete setup
yarn hardhat deploy-bridge-l1 --implementation --proxy --network ethereum
```

### Pool Deployment
Deploy LancaCanonicalBridgePool contracts with proxy setup and pool configuration.

```bash
yarn hardhat deploy-pool [--implementation] [--proxy] [--addpool] --chain <chain_name> --network <network_name>
```

**Flags:**
- `--implementation` - Deploy pool implementation
- `--proxy` - Deploy proxy and proxy admin for pool
- `--addpool` - Add pool to L1 Bridge contract

**Parameters:**
- `--chain` - Destination chain name for the pool (required)

**Examples:**
```bash
# Deploy pool implementation only
yarn hardhat deploy-pool --implementation --chain arbitrum --network arbitrum

# Deploy proxy and admin only
yarn hardhat deploy-pool --proxy --chain arbitrum --network arbitrum

# Deploy implementation + proxy with automatic upgrade
yarn hardhat deploy-pool --implementation --proxy --chain arbitrum --network arbitrum

# Deploy complete setup and add pool to L1 Bridge
yarn hardhat deploy-pool --implementation --proxy --addpool --chain arbitrum --network arbitrum
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
yarn hardhat add-lane --chainid <destination_chain_id> --network <network_name>
```

**Parameters:**
- `--chainid` - Destination chain id for the lane (required)

**Examples:**
```bash
# Add lane for Arbitrum chain
yarn hardhat add-lane --chainid 42161 --network ethereum
```

### Send Tokens
Send tokens from one network to another via bridge.

```bash
yarn hardhat send-token --dstchain <destination_network> --amount <amount> --gaslimit <gas_limit> --network <source_network>
```

**Parameters:**
- `--dstchain` - Destination network name (e.g., 'arbitrumSepolia', 'baseSepolia')
- `--amount` - Amount of USDC to send (e.g., '10.5')
- `--gaslimit` - Gas limit for destination transaction (e.g., '200000')

**Examples:**
```bash
# Send 10.5 USDC from Ethereum Sepolia to Arbitrum Sepolia
yarn hardhat send-token --dstchain arbitrumSepolia --amount 10.5 --gaslimit 200000 --network ethereumSepolia

# Send 5 USDC from Arbitrum Sepolia to Base Sepolia
yarn hardhat send-token --dstchain baseSepolia --amount 5 --gaslimit 150000 --network arbitrumSepolia
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