# Delivery DApp - Flutter Implementation

A decentralized delivery tracking system built with Flutter, Firebase, and Ethereum blockchain integration. This application serves as a research platform for studying blockchain technology in supply chain transparency, user experience, and technical implementation challenges.

## 🎯 Research Questions

This application is designed to answer three key research questions:

1. **Q1: Transparency** - Can blockchain technology enhance supply chain transparency in last-mile delivery operations?
2. **Q2: UX & Cost** - How does decentralization impact user experience and cost efficiency in delivery platforms?
3. **Q3: Technical Challenges** - What technical challenges exist in implementing blockchain-based logistics systems?

## 🔒 Test Network Only Policy

**IMPORTANT**: This application is configured for **research purposes only** and **strictly enforces test networks**:

- ✅ **Allowed**: Hardhat Local (Chain ID: 31337)
- ❌ **Blocked**: All mainnets and other test networks
- 🛡️ **Security**: All transactions are blocked on non-allowed networks
- 📱 **Mobile**: WalletConnect enforces Hardhat-only connections

## 🏗️ Architecture

### Technology Stack
- **Frontend**: Flutter (Web + Mobile)
- **Backend**: Firebase Firestore
- **Blockchain**: Ethereum (via web3dart)
- **Wallet Integration**: MetaMask, WalletConnect
- **Token**: RLE (custom ERC-20 token)

### Key Components
- **Smart Contracts**: DeliveryToken, DeliveryTrackingSystem, RatingSystem, BalancedRewardSystem, SimpleDeliverySystem, DecentralizationPhase, RLEGovernor, and TimelockController
- **State Management**: Provider pattern
- **Navigation**: GoRouter
- **Analytics**: Firestore-based data collection
- **UI**: Material Design 3

## 🚀 Setup Instructions

### Prerequisites
- Flutter SDK (>=3.0.0)
- Node.js and npm
- MetaMask browser extension
- Firebase project with Firestore enabled

### 1. Clone and Install Dependencies

```bash
cd app
flutter pub get
```

### 2. Firebase Configuration

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Firestore Database
3. Download `google-services.json` and place it in `android/app/`
4. The `firebase_options.dart` file is already configured

### 3. Blockchain Configuration

The app loads contract addresses from `assets/config/contracts.localhost.json`, then `assets/config/contracts.json`. In development it uses git-ignored `assets/config/dev_host.json` when that file exists, and otherwise `10.0.2.2`.

### 4. Environment Variables

Create a `.env` file in the `app` directory:

```env
RPC_URL=http://localhost:8545
CHAIN_ID=31337
NETWORK_NAME=Hardhat Local
CURRENCY_SYMBOL=ETH
BLOCK_EXPLORER_URL=
DEBUG_MODE=true
ENABLE_ANALYTICS=true
```

### 5. Start Hardhat Node

From the `blockchain/` directory:

```bash
npx hardhat node --hostname 0.0.0.0
```

### 6. Run the Application

```bash
# For web development
flutter run -d chrome

# For mobile development
flutter run
```

### 7. Setup MetaMask Network

Add the local network in MetaMask by hand:

1. Network Name: Hardhat Local
2. RPC URL: `http://127.0.0.1:8545` on the host machine, or the host in `dev_host.json` for a device
3. Chain ID: 31337 (0x7A69)
4. Currency Symbol: ETH

### 8. Import Test Accounts

These are the public Hardhat test keys.

**Deployer and Bootstrap founder (account #0):**
- Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

**Localhost hybrid council (account #1):**
- Address: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
- Private Key: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d`

Further Hardhat accounts can be used as customers and drivers.

## 📊 Data Model

### Firestore Collections

#### Users Collection (`users/{address}`)
```json
{
  "address": "0x...",
  "providerType": "MetaMask|WalletConnect",
  "createdAt": "timestamp",
  "lastActiveAt": "timestamp"
}
```

#### Deliveries Collection (`deliveries/{deliveryId}`)
```json
{
  "id": "deliveryId",
  "customer": "0x...",
  "courier": "0x...",
  "pickupAddress": "string",
  "deliveryAddress": "string",
  "priceWei": "string",
  "priceTokenSymbol": "RLE",
  "description": "string",
  "status": "pending|accepted|inTransit|delivered|cancelled",
  "createdAt": "timestamp",
  "completedAt": "timestamp",
  "lastSyncedAt": "timestamp"
}
```

#### Delivery Events Collection (`deliveryEvents/{deliveryId}/events/{eventId}`)
```json
{
  "type": "Created|Accepted|Completed|Cancelled",
  "txHash": "0x...",
  "blockNumber": "number",
  "emitter": "0x...",
  "data": "object",
  "timestamp": "timestamp"
}
```

#### Transactions Collection (`transactions/{txHash}`)
```json
{
  "action": "create|accept|complete|cancel",
  "providerType": "MetaMask|WalletConnect",
  "submittedAt": "timestamp",
  "minedAt": "timestamp",
  "confirmations": "number",
  "gasUsed": "string",
  "effectiveGasPriceWei": "string",
  "nativeFeeWei": "string",
  "status": "success|reverted|failed",
  "errorCode": "string",
  "errorMessage": "string"
}
```

#### UX Feedback Collection (`uxFeedback/{sessionId}`)
```json
{
  "action": "createDelivery|acceptDelivery|completeDelivery",
  "providerType": "MetaMask|WalletConnect",
  "perceivedEase": "1-5",
  "perceivedSpeed": "1-5",
  "notes": "string",
  "timestamp": "timestamp"
}
```

#### Challenges Collection (`challenges/{id}`)
```json
{
  "category": "network|wallet|contract|ui",
  "context": "string",
  "errorCode": "string",
  "message": "string",
  "frequency": "number",
  "firstSeenAt": "timestamp",
  "lastSeenAt": "timestamp"
}
```

## 🔧 Key Features

### 1. Wallet Integration
- **MetaMask**: Browser-based wallet connection
- **WalletConnect**: Mobile wallet support
- **Private Key**: Direct wallet connection (development)

### 2. Delivery Management
- **Create Delivery**: Multi-step form with validation
- **Track Status**: Real-time status updates
- **Complete Delivery**: The customer confirms completion. During Bootstrap the founder may also complete it. There is no contract accept step. The app's accept path is a placeholder.

### 3. Analytics Dashboard
- **Transparency Metrics**: Event coverage, audit trails
- **UX & Cost Analysis**: Transaction costs, user satisfaction
- **Technical Challenges**: Error tracking, failure analysis

### 4. Research Instrumentation
- **Transaction Tracking**: Latency, gas costs, success rates
- **User Feedback**: Perceived ease and speed ratings
- **Error Categorization**: Technical challenge identification
- **Data Export**: Firestore-based analytics

## 📱 User Flows

### Customer Flow
1. Connect wallet (MetaMask/WalletConnect)
2. Create a delivery. Payment is recorded in fiat cents; rewards are paid in RLE
3. Track delivery status
4. View delivery history
5. Access analytics dashboard

### Driver Flow
1. Connect wallet
2. View deliveries
3. Update delivery status
4. View earnings and analytics

The customer, or the founder during Bootstrap, confirms completion on the contract. The driver accept action in the app does not call the contract.

## 🔍 Research Data Collection

### Metrics Captured
- **Transaction Metrics**: Latency, gas costs, success rates
- **User Experience**: Ease ratings, speed perceptions
- **Technical Issues**: Error categories, failure patterns
- **Transparency**: Event coverage, audit trail completeness

### Analytics Dashboard
Access the analytics dashboard via the analytics button in the app bar to view:
- **Q1 Analysis**: Blockchain transparency metrics
- **Q2 Analysis**: Decentralization impact on UX and costs
- **Q3 Analysis**: Technical implementation challenges

## 🛠️ Development

### Project Structure
```
app/
├── lib/
│   ├── constants/          # Environment configuration
│   ├── models/            # Data models
│   ├── screens/           # UI screens
│   │   ├── customer/      # Customer-specific screens
│   │   ├── driver/        # Driver-specific screens
│   │   └── analytics/     # Research analytics
│   ├── services/          # Business logic
│   │   ├── blockchain/    # Blockchain integration
│   │   ├── delivery/      # Delivery management
│   │   └── firestore/     # Firebase integration
│   ├── utils/             # Utility functions
│   └── widgets/           # Reusable UI components
├── assets/
│   ├── abi/              # Smart contract ABIs
│   └── config/           # Contract configurations
└── web/                  # Web-specific files
```

### Key Services
- **WalletService**: Wallet connection management
- **DeliveryService**: Delivery business logic
- **ContractService**: Blockchain interaction
- **AnalyticsService**: Firestore data persistence
- **TransactionTracker**: Transaction monitoring

## 🧪 Testing

### Manual Testing
1. **Wallet Connection**: Test MetaMask and WalletConnect
2. **Delivery Creation**: Create deliveries with different RLE reward outcomes
3. **Driver Operations**: Review deliveries. Completion is a customer confirmation, not a driver accept call.
4. **Analytics**: Verify data collection in Firestore
5. **Error Handling**: Test network failures and edge cases

### Data Validation
- Check Firestore collections for proper data structure
- Verify transaction tracking accuracy
- Validate analytics calculations
- Test error categorization

## 📈 Research Analysis

### Data Export
Analytics data is stored in Firestore and can be exported for further analysis:

1. **Transparency Analysis**: Event coverage, audit trail completeness
2. **Cost Analysis**: Gas costs, transaction fees, efficiency metrics
3. **UX Analysis**: User satisfaction, perceived performance
4. **Technical Analysis**: Error patterns, failure modes, challenges

### Research Findings
The analytics dashboard provides insights into:
- Blockchain transparency benefits in delivery operations
- Trade-offs between decentralization and user experience
- Technical challenges in blockchain logistics implementation

## 🚨 Troubleshooting

### Common Issues
1. **Wallet Connection**: Ensure MetaMask is installed and unlocked
2. **Contract Errors**: Verify contract addresses in config files
3. **Firebase Errors**: Check Firestore rules and authentication
4. **Network Issues**: Ensure RPC endpoint is accessible

### Debug Mode
Enable debug logging by setting:
```dart
debugPrint('Debug: $message');
```

## Known prototype limitations

- The Flutter app does not provide a governance interface. It does not show phase status or call `advancePhase`. Creating proposals, delegating, and voting must be done through scripts or an external governor interface.
- The Hybrid controller must be a real multisignature wallet (for example a Safe with threshold at least 2) in any production or public-testnet deployment. On localhost it is a single Hardhat test account.
- Contracts are not upgradeable. Replacing one requires a governance-approved redeployment.
- Customers confirm deliveries, so colluding accounts (Sybil wallets) could create self-dealing deliveries to earn RLE and inflate milestone metrics. Reward limits slow this per address but do not prevent it across many addresses.
- Firestore rules and password handling are development-only, not production-ready.
- Three gas-threshold tests fail (`processReward`, `addCheckpoint`, and the full delivery flow). Measured values are reported instead of loosening the thresholds.
- No independent security audit has been performed.

## 📄 License

This project is part of a Master's thesis research on blockchain technology in supply chain management.

## 🤝 Contributing

This is a research project. For questions or issues, please contact the research team.

---

**Note**: This application is designed for research purposes and demonstrates blockchain integration in delivery logistics. Ensure proper testing before production use.