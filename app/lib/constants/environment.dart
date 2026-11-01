/// Environment configuration for the delivery DApp
/// 
/// Controls whether the app runs in development mode (local Hardhat)
/// or production mode (Sepolia testnet)

class Environment {
  // ========== ENVIRONMENT TOGGLE ==========
  // Set this to false when deploying to production/demo
  static const bool isDevelopment = true;
  
  // ========== PRODUCTION CONFIGURATION ==========
  // Sepolia Testnet - Public Ethereum test network
  // Get your free API key from: https://alchemy.com or https://infura.io
  static const String productionRpcUrl = 'https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY';
  static const int productionChainId = 11155111;  // Sepolia
  static const String productionChainIdHex = '0xaa36a7';  // Sepolia in hex
  static const String productionNetworkName = 'Sepolia Testnet';
  
  // ========== DEVELOPMENT CONFIGURATION ==========
  // Local Hardhat. The committed default host is 10.0.2.2 (Android emulator).
  // deploy-thesis.ts writes a detected LAN address to assets/config/dev_host.json,
  // which ContractService reads in development.
  static const int developmentChainId = 31337;  // Hardhat
  static const String developmentChainIdHex = '0x7A69';  // Hardhat in hex
  static const String developmentNetworkName = 'Hardhat Local';
  
  // ========== COMPUTED PROPERTIES ==========
  // These automatically return the correct values based on isDevelopment
  
  static int get chainId => isDevelopment ? developmentChainId : productionChainId;
  static String get chainIdHex => isDevelopment ? developmentChainIdHex : productionChainIdHex;
  static String get networkName => isDevelopment ? developmentNetworkName : productionNetworkName;
  
  // Note: RPC URL is handled in contract_service.dart because dev mode uses dynamic IP
  static String get productionRpc => productionRpcUrl;
}

