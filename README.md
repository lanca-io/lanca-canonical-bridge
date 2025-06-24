# Hardhat Tasks

## Available Tasks

### Bridge Deployment
Deploy LancaCanonicalBridge contracts with flexible options.

```bash
yarn hardhat deploy-bridge [--implementation] [--proxy] [--pool] --network <network_name>
```

**Flags:**
- `--implementation` - Deploy bridge implementation contract
- `--proxy` - Deploy proxy and proxy admin contracts  
- `--pool` - Deploy bridge pool contract (if you have USDC address)

**Examples:**
```bash
# Deploy implementation only
yarn hardhat deploy-bridge --implementation --network arbitrum

# Deploy proxy and admin only
yarn hardhat deploy-bridge --proxy --network arbitrum

# Deploy implementation + proxy (with automatic upgrade)
yarn hardhat deploy-bridge --implementation --proxy --network arbitrum

# Deploy all components
yarn hardhat deploy-bridge --implementation --proxy --pool --network arbitrum
```

### Fiat Token Deployment
Deploy USDC-compatible FiatToken contracts.

```bash
yarn hardhat deploy-fiat-token [--implementation] [--proxy] --network <network_name>
```

**Flags:**
- `--implementation` - Deploy token implementation contract
- `--proxy` - Deploy proxy contract

**Examples:**
```bash
# Deploy implementation only
yarn hardhat deploy-fiat-token --implementation --network arbitrum

# Deploy complete setup with configuration
yarn hardhat deploy-fiat-token --implementation --proxy --network arbitrum
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