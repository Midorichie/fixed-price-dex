# Advanced DeFi Protocol

A comprehensive decentralized finance protocol built on Stacks, featuring an Automated Market Maker (AMM) DEX, liquidity pools, governance system, and price oracles.

## 🌟 Features

### Core Protocol
- **Enhanced Vault System**: Secure token storage with liquidity pool integration
- **AMM DEX**: Automated market maker with constant product formula
- **Liquidity Pools**: Users can provide liquidity and earn fees
- **Governance**: Token-based voting system for protocol decisions
- **Price Oracle**: External price feeds and time-weighted average prices (TWAP)

### Security Enhancements
- **Emergency Pause**: Admin can pause contracts during emergencies
- **Failed Transaction Tracking**: Monitor and limit suspicious activity
- **Slippage Protection**: Prevent excessive slippage on trades
- **Access Control**: Role-based permissions for sensitive functions

## 📁 Contract Architecture

```
contracts/
├── vault.clar              # Enhanced vault with AMM integration
├── dex.clar               # Original simple DEX (kept for compatibility)
├── governance.clar        # Decentralized governance system
├── price-oracle.clar      # Price feeds and TWAP calculations
├── token-a.clar          # SIP-010 compliant token A
├── token-b.clar          # SIP-010 compliant token B
└── traits/
    └── sip-010-trait.clar # SIP-010 token standard trait
```

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks CLI](https://docs.stacks.co/docs/write-smart-contracts/cli-wallet-quickstart) configured

### Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd advanced-defi-protocol
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

4. Start development console:
```bash
clarinet console
```

## 🔧 Contract Functions

### Vault Contract (vault.clar)

#### Core Functions
- `deposit(amount, token)` - Deposit tokens into vault
- `withdraw(amount, token)` - Withdraw tokens from vault
- `create-pool(token-a, token-b, amount-a, amount-b)` - Create new liquidity pool
- `add-liquidity(token-a, token-b, amount-a, amount-b, min-shares)` - Add liquidity to existing pool
- `swap-exact-tokens(token-in, token-out, amount-in, min-amount-out)` - Swap tokens using AMM

#### Admin Functions
- `pause-contract()` - Pause all contract operations
- `unpause-contract()` - Resume contract operations  
- `set-fee-rate(new-rate)` - Update trading fee rate

#### View Functions
- `get-balance(user, token)` - Get user's token balance in vault
- `get-pool-info(token-a, token-b)` - Get liquidity pool information
- `get-lp-shares(user, token-a, token-b)` - Get user's LP token shares
- `get-swap-quote(token-in, token-out, amount-in)` - Get swap price quote

### Governance Contract (governance.clar)

#### Proposal Management
- `create-proposal(title, description, type, parameter)` - Create governance proposal
- `vote(proposal-id, vote-for)` - Vote on proposal
- `execute-proposal(proposal-id)` - Execute passed proposal

#### Voting Power
- `update-voting-power(token)` - Update voting power based on token balance
- `delegate-votes(delegate, amount)` - Delegate voting power to another user

#### View Functions
- `get-proposal(proposal-id)` - Get proposal details
- `get-proposal-status(proposal-id)` - Get current proposal status
- `get-voting-power-info(user)` - Get user's voting power information

### Price Oracle Contract (price-oracle.clar)

#### Oracle Management
- `add-oracle(oracle-address, token-a, token-b, update-frequency)` - Add authorized oracle
- `submit-price(token-a, token-b, price, confidence)` - Submit price update (oracles only)

#### Price Queries
- `get-price(token-a, token-b)` - Get current oracle price
- `get-twap(token-a, token-b, period)` - Get time-weighted average price
- `detect-arbitrage(token-a, token-b)` - Check for arbitrage opportunities

## 📊 Usage Examples

### Creating a Liquidity Pool

```clarity
;; Create pool with 1000 Token A and 2000 Token B
(contract-call? .vault create-pool .token-a .token-b u1000 u2000)
```

### Swapping Tokens

```clarity
;; Swap 100 Token A for Token B (minimum 190 Token B expected)
(contract-call? .vault swap-exact-tokens .token-a .token-b u100 u190)
```

### Creating Governance Proposal

```clarity
;; Propose to change fee rate to 0.5% (50/10000)
(contract-call? .governance create-proposal 
  "Reduce Trading Fees" 
  "Lower fees to attract more volume" 
  u1 
  u50)
```

### Submitting Oracle Price

```clarity
;; Oracle submits price: 1 Token A = 2.05 Token B
(contract-call? .price-oracle submit-price 
  .token-a 
  .token-b 
  u205000000  ;; 2.05 * 10^8
  u9500)      ;; 95% confidence
```

## 🔒 Security Features

### Access Control
- **Owner-only functions**: Critical admin functions restricted to contract owner
- **Oracle authorization**: Only authorized oracles can submit price data
- **Voting requirements**: Minimum token balance required for proposals

### Economic Security
- **Slippage protection**: Trades require minimum output amounts
- **Fee collection**: Trading fees collected to protocol treasury
- **Liquidity requirements**: Minimum liquidity thresholds for pools

### Operational Security
- **Emergency pause**: Halt operations during security incidents
- **Failed transaction monitoring**: Track suspicious user activity
- **Price staleness checks**: Reject outdated oracle prices

## 🧪 Testing

### Unit Tests
```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/vault_test.ts
```

### Integration Tests
```bash
# Test full protocol flow
clarinet test tests/integration_test.ts
```

### Manual Testing
```bash
# Start interactive console
clarinet console

# Deploy contracts
::deploy_contracts

# Mint test tokens
(contract-call? .token-a mint u10000 tx-sender)
(contract-call? .token-b mint u20000 tx-sender)
```

## 🚢 Deployment

### Devnet Deployment
```bash
clarinet deployments generate --devnet
clarinet deployments apply --devnet
```

### Testnet Deployment
```bash
# Update wallet in Clarinet.toml
clarinet deployments generate --testnet
clarinet deployments apply --testnet
```

## 📈 Advanced Features

### Automated Market Making
- **Constant Product Formula**: x * y = k for price determination
- **Dynamic Fees**: Fee rates adjustable through governance
- **Price Impact Calculation**: Real-time price impact estimation

### Governance System
- **Proposal Types**: Fee changes, contract pauses, upgrades
- **Voting Periods**: Configurable voting windows
- **Quorum Requirements**: Minimum participation for valid votes
- **Delegation**: Users can delegate voting power

### Oracle Integration
- **Multiple Price Sources**: Support for multiple oracle providers
- **TWAP Calculations**: Time-weighted average price computation
- **Arbitrage Detection**: Identify price discrepancies between pools and oracles
- **Price Confidence**: Oracles provide confidence scores for submissions

## �� Roadmap

### Phase 1 ✅
- [x] Basic vault and DEX functionality
- [x] SIP-010 token implementation
- [x] Simple fixed-rate swaps

### Phase 2 ✅ (Current)
- [x] AMM liquidity pools
- [x] Governance system
- [x] Price oracle integration
- [x] Enhanced security features

### Phase 3 🚧 (Planned)
- [ ] Yield farming rewards
- [ ] Cross-chain bridge integration
- [ ] Advanced order types (limit orders)
- [ ] Flash loan functionality
- [ ] Multi-hop routing optimization

### Phase 4 🔮 (Future)
- [ ] Layer 2 scaling solutions
- [ ] NFT marketplace integration
- [ ] Synthetic asset creation
- [ ] Decentralized insurance pools

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and add tests
4. Run tests: `clarinet test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Stacks Documentation](https://docs.stacks.co)
- **Community**: [Stacks Discord](https://discord.gg/zrvWsQC)
- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
