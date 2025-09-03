# Delivery DApp - Flutter Application

flutter test test/services/blockchain/rating_service_test.dart
flutter test test/services/blockchain/staking_service_test.dart
flutter test test/widgets/rating_widget_test.dart
flutter test test/widgets/staking_widget_test.dart

flutter test integration_test/rating_flow_test.dart
flutter test integration_test/staking_flow_test.dart

This is the Flutter application for the Delivery DApp, a decentralized delivery tracking system built on the Ethereum blockchain.

## Features

- Cross-platform support (Web, Android, iOS)
- Wallet integration (MetaMask for web, WalletConnect for mobile)
- Real-time delivery tracking
- Secure payment processing
- Driver staking and rewards
- Rating and reputation system

## Getting Started

### Prerequisites

- Flutter SDK (latest version)
- Android Studio (for Android development)
- Xcode (for iOS development, Mac only)
- Node.js and npm (for blockchain interaction)

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/delivery-dapp.git
cd delivery-dapp/app
```

2. Install dependencies
```bash
flutter pub get
```

3. Set up environment variables
- Copy `.env.example` to `.env`
- Fill in your API keys and contract addresses

4. Run the application
```bash
# For web
flutter run -d chrome

# For Android
flutter run -d android

# For iOS
flutter run -d ios
```

## Project Structure

```
app/
├── lib/
│   ├── screens/           # App screens
│   ├── widgets/           # Reusable widgets
│   ├── services/          # Business logic
│   ├── models/            # Data models
│   └── utils/             # Utility functions
├── web/                   # Web-specific code
├── android/               # Android-specific code
└── ios/                   # iOS-specific code
```

## Blockchain Integration

The application integrates with the Ethereum blockchain using:
- web3dart for blockchain interaction
- MetaMask for web wallet connection
- WalletConnect for mobile wallet connection

## License

This project is licensed under the MIT License - see the LICENSE file for details. 