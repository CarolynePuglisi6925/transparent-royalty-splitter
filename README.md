# Transparent Royalty Splitter

## Overview

Transparent Royalty Splitter is an on-chain solution focusing on security, composability, and transparent accounting for royalty distribution. This platform provides automated, trustless splitting of royalty payments among multiple beneficiaries through smart contracts on the Stacks blockchain.

## Features

- **Transparent Accounting**: All royalty distributions recorded on-chain
- **Automated Splitting**: Smart contract-based automatic payment distribution
- **Factory Pattern**: Deploy new splitter instances through factory contract
- **Registry System**: Centralized tracking of all deployed splitters
- **Immutable Rules**: Once configured, split percentages are transparent and verifiable

## Architecture

### Royalty Splitter Factory Contract

Factory contract for deploying new instances and maintaining registries:
- Creates new royalty splitter instances
- Maintains registry of all deployed splitters
- Tracks deployment history
- Validates configuration parameters
- Provides template upgrades

## Smart Contracts

### royalty-splitter-factory.clar

Comprehensive factory implementation with:
- Instance deployment
- Configuration validation
- Registry management
- Template versioning
- Access controls

## Getting Started

### Prerequisites

- Clarinet installed
- Node.js and npm
- Stacks wallet

### Installation

```bash
git clone <repository-url>
cd transparent-royalty-splitter
npm install
clarinet check
```

## Usage

### Deploy New Splitter

Create a royalty splitter by calling the factory with beneficiary shares.

### Distribute Royalties

Send funds to splitter contract for automatic distribution.

## License

MIT License
