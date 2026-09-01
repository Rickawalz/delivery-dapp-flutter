import '../services/blockchain/contract_service.dart'; // Import to access HARDHAT_RPC_IP
import '../constants/environment.dart';

/// Utility for managing allowed blockchain networks
/// Supports both development (Hardhat) and production (Sepolia) modes
class AllowedNetworks {
  /// Hardhat configuration (development)
  static const int hardhatChainId = 31337;
  static const String hardhatChainIdHex = '0x7A69';
  static const String hardhatNetworkName = 'Hardhat Local';
  
  /// Sepolia configuration (production)
  static const int sepoliaChainId = 11155111;
  static const String sepoliaChainIdHex = '0xaa36a7';
  static const String sepoliaNetworkName = 'Sepolia Testnet';
  
  /// List of allowed chain IDs based on environment
  static List<int> get allowedChainIds => Environment.isDevelopment
      ? [hardhatChainId]    // Development: Hardhat only
      : [sepoliaChainId];   // Production: Sepolia only
  
  /// Network information mapping based on environment
  static Map<int, NetworkInfo> get networkInfo => {
    // Hardhat (development mode)
    if (Environment.isDevelopment)
      hardhatChainId: NetworkInfo(
        chainId: hardhatChainId,
        name: hardhatNetworkName,
        rpcUrl: 'http://$HARDHAT_RPC_IP:8545',  // Dynamic IP from deploy script
        currencySymbol: 'ETH',
        blockExplorer: null,
        isLocal: true,
      ),
    
    // Sepolia (production mode)
    if (!Environment.isDevelopment)
      sepoliaChainId: NetworkInfo(
        chainId: sepoliaChainId,
        name: sepoliaNetworkName,
        rpcUrl: Environment.productionRpc,
        currencySymbol: 'ETH',
        blockExplorer: 'https://sepolia.etherscan.io',
        isLocal: false,
      ),
  };
  
  /// Check if a chain ID is allowed
  static bool isAllowed(int? chainId) {
    if (chainId == null) return false;
    return allowedChainIds.contains(chainId);
  }
  
  /// Get network name for a chain ID
  static String nameFor(int? chainId) {
    if (chainId == null) return 'Unknown';
    return networkInfo[chainId]?.name ?? 'Other';
  }
  
  /// Get network info for a chain ID
  static NetworkInfo? infoFor(int? chainId) {
    if (chainId == null) return null;
    return networkInfo[chainId];
  }
  
  /// Get the preferred network (Hardhat)
  static NetworkInfo get preferredNetwork => networkInfo[hardhatChainId]!;
  
  /// Check if chain ID is local development network
  static bool isLocal(int? chainId) {
    return networkInfo[chainId]?.isLocal ?? false;
  }
  
  /// Get allowed chain IDs as hex strings
  static List<String> get allowedChainIdsHex => 
      allowedChainIds.map((id) => '0x${id.toRadixString(16)}').toList();
}

/// Network information model
class NetworkInfo {
  final int chainId;
  final String name;
  final String rpcUrl;
  final String currencySymbol;
  final String? blockExplorer;
  final bool isLocal;
  
  const NetworkInfo({
    required this.chainId,
    required this.name,
    required this.rpcUrl,
    required this.currencySymbol,
    this.blockExplorer,
    required this.isLocal,
  });
  
  String get chainIdHex => '0x${chainId.toRadixString(16)}';
  
  @override
  String toString() => '$name (Chain ID: $chainId)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkInfo &&
          runtimeType == other.runtimeType &&
          chainId == other.chainId;
  
  @override
  int get hashCode => chainId.hashCode;
}
