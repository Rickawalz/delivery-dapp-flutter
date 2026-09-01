import 'package:flutter/foundation.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import '../../utils/allowed_networks.dart';
import '../../constants/environment.dart';

/// WalletConnect Service for mobile wallet integration using WalletConnect v2
/// 
/// This service uses the WalletConnect v2 protocol for connecting to mobile wallets.
/// It provides QR code-based pairing and supports transaction signing.

class WalletConnectService extends ChangeNotifier {
  Web3App? _web3App;
  bool _isConnected = false;
  String? _walletAddress;
  int? _chainId = 31337; // Hardhat network
  SessionData? _currentSession;
  String? _pairingUri;
  Future<SessionData>? _pendingSession;

  bool get isConnected => _isConnected;
  String? get walletAddress => _walletAddress;
  int? get chainId => _chainId;
  Web3App? get web3App => _web3App;
  SessionData? get currentSession => _currentSession;
  String? get pairingUri => _pairingUri;

  Future<void> initialize() async {
    try {
      debugPrint('WalletConnect v2 service initializing...');
      
      // Initialize WalletConnect v2 with project ID
      _web3App = await Web3App.createInstance(
        projectId: 'bfc0a8f7a430e193c9a6dd70a07ccd64',
        metadata: const PairingMetadata(
          name: 'Delivery DApp',
          description: 'Decentralized delivery tracking system',
          url: 'https://delivery-dapp.com',
          icons: ['https://delivery-dapp.com/icon.png'],
        ),
      );

      // Set up event listeners for v2
      _web3App!.onSessionConnect.subscribe(_onSessionConnect);
      _web3App!.onSessionUpdate.subscribe(_onSessionUpdate);
      _web3App!.onSessionDelete.subscribe(_onSessionDelete);

      debugPrint('WalletConnect v2 service initialized');
      
      // Try to restore previous session from storage
      await _restoreSession();
    } catch (e) {
      debugPrint('WalletConnect v2 initialization error: $e');
    }
  }

  /// Restore previous WalletConnect session from storage
  /// This allows users to stay connected after page refresh
  Future<void> _restoreSession() async {
    if (_web3App == null) return;
    
    try {
      // Get all active sessions from storage
      final sessions = _web3App!.sessions.getAll();
      
      if (sessions.isEmpty) {
        debugPrint('WalletConnect v2: No existing sessions found');
        return;
      }
      
      debugPrint('WalletConnect v2: Found ${sessions.length} existing session(s)');
      
      // Use the most recent session
      final session = sessions.last;
      
      // Extract account info - look for account on expected chain
      final namespace = session.namespaces['eip155'];
      if (namespace != null && namespace.accounts.isNotEmpty) {
        // Look for account on the expected chain based on environment
        final expectedChainPrefix = 'eip155:${Environment.chainId}:';
        final targetAccount = namespace.accounts.firstWhere(
          (account) => account.startsWith(expectedChainPrefix),
          orElse: () => '',
        );
        
        if (targetAccount.isEmpty) {
          debugPrint('WalletConnect v2: No ${Environment.networkName} account in stored session');
          // Clean up session from different network
          await _web3App!.disconnectSession(
            topic: session.topic,
            reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
          );
          return;
        }
        
        final accountParts = targetAccount.split(':');
        if (accountParts.length >= 3) {
          _walletAddress = accountParts[2];
          _chainId = int.tryParse(accountParts[1]);
          _currentSession = session;
          _isConnected = true;
          
          debugPrint('✅ WalletConnect v2: Session restored successfully');
          debugPrint('   📱 Address: $_walletAddress');
          debugPrint('   🔗 Chain ID: $_chainId');
          debugPrint('   🌐 Network: ${Environment.networkName}');
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('WalletConnect v2: Session restore error: $e');
      // Don't throw - just continue without restored session
    }
  }

  Future<String> generatePairingUri() async {
    try {
      if (_web3App == null) {
        await initialize();
      }

      debugPrint('WalletConnect v2 connection requested');
      
      // Create connection request for current environment's network
      final ConnectResponse connectResponse = await _web3App!.connect(
        requiredNamespaces: {
          'eip155': RequiredNamespace(
            chains: [
              Environment.isDevelopment 
                  ? 'eip155:31337'      // Hardhat in development
                  : 'eip155:11155111'   // Sepolia in production
            ],
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'eth_sign',
              'personal_sign',
              'eth_signTypedData',
            ],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
      );

      // Get the pairing URI for QR code display
      _pairingUri = connectResponse.uri.toString();
      debugPrint('WalletConnect v2 pairing URI: $_pairingUri');
      
      // Store the session future for later use
      _pendingSession = connectResponse.session.future;
      
      // Notify listeners so UI can display QR code
      notifyListeners();
      
      return _pairingUri!;
      
    } catch (e) {
      debugPrint('WalletConnect v2 connection error: $e');
      _isConnected = false;
      _walletAddress = null;
      _chainId = null;
      _pairingUri = null;
      _pendingSession = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> waitForConnection() async {
    if (_pendingSession == null) {
      throw Exception('No pending session. Call generatePairingUri() first.');
    }

    try {
      debugPrint('Waiting for WalletConnect v2 session approval...');
      
      // Wait for session approval
      final SessionData session = await _pendingSession!;
      
      _onSessionConnect(SessionConnect(session));
      
    } catch (e) {
      debugPrint('WalletConnect v2 session approval error: $e');
      _isConnected = false;
      _walletAddress = null;
      _chainId = null;
      _pairingUri = null;
      _pendingSession = null;
      notifyListeners();
      rethrow;
    }
  }

  void _onSessionConnect(SessionConnect? event) {
    if (event == null) return;
    
    debugPrint('WalletConnect v2 connected: ${event.session.namespaces}');
    
    final session = event.session;
    _currentSession = session;
    
    // Extract account and chain info from namespaces
    final namespace = session.namespaces['eip155'];
    if (namespace != null && namespace.accounts.isNotEmpty) {
      // Look for account on the expected chain based on environment
      final expectedChainPrefix = 'eip155:${Environment.chainId}:';
      final targetAccount = namespace.accounts.firstWhere(
        (account) => account.startsWith(expectedChainPrefix),
        orElse: () => namespace.accounts.first,
      );
      
      final accountParts = targetAccount.split(':');
      if (accountParts.length >= 3) {
        _walletAddress = accountParts[2];
        _chainId = int.tryParse(accountParts[1]);
      }
    }
    
    // Verify that we have an account on the expected chain
    if (_chainId != Environment.chainId) {
      debugPrint('WalletConnect v2: No ${Environment.networkName} account found in session, disconnecting');
      debugPrint('Expected chain ID: ${Environment.chainId}, Got: $_chainId');
      debugPrint('Available accounts: ${namespace?.accounts}');
      disconnect();
      return;
    }
    
    _isConnected = true;
    _pairingUri = null; // Clear pairing URI after connection
    debugPrint('WalletConnect v2: Successfully connected to ${Environment.networkName} with address $_walletAddress');
    notifyListeners();
  }

  void _onSessionUpdate(SessionUpdate? event) {
    if (event == null) return;
    
    debugPrint('WalletConnect v2 session updated: ${event.namespaces}');
    
    // Update session data
    if (_currentSession != null) {
      // Extract updated account info - look for expected chain account
      final namespace = event.namespaces['eip155'];
      if (namespace != null && namespace.accounts.isNotEmpty) {
        // Look for account on the expected chain based on environment
        final expectedChainPrefix = 'eip155:${Environment.chainId}:';
        final targetAccount = namespace.accounts.firstWhere(
          (account) => account.startsWith(expectedChainPrefix),
          orElse: () => '',
        );
        
        if (targetAccount.isEmpty) {
          debugPrint('WalletConnect v2: Session updated but no ${Environment.networkName} account found, disconnecting');
          disconnect();
          return;
        }
        
        final accountParts = targetAccount.split(':');
        if (accountParts.length >= 3) {
          _walletAddress = accountParts[2];
          _chainId = int.tryParse(accountParts[1]);
        }
      }
      
      debugPrint('WalletConnect v2: Session update successful, still on ${Environment.networkName}');
      notifyListeners();
    }
  }

  void _onSessionDelete(SessionDelete? event) {
    if (event == null) return;
    
    debugPrint('WalletConnect v2 session deleted');
    _isConnected = false;
    _walletAddress = null;
    _chainId = null;
    _currentSession = null;
    _pairingUri = null;
    notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      debugPrint('WalletConnect v2 disconnecting...');
      
      if (_web3App != null && _currentSession != null) {
        await _web3App!.disconnectSession(
          topic: _currentSession!.topic,
          reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
        );
      }
      
      _isConnected = false;
      _walletAddress = null;
      _chainId = null;
      _currentSession = null;
      _pairingUri = null;
      _pendingSession = null;
      
      notifyListeners();
      
      debugPrint('WalletConnect v2 disconnected');
    } catch (e) {
      debugPrint('WalletConnect v2 disconnect error: $e');
    }
  }

  Future<String> sendTransaction({
    required String to,
    required String value,
    String? data,
  }) async {
    if (!_isConnected || _web3App == null || _currentSession == null) {
      throw Exception('Wallet not connected');
    }

    try {
      debugPrint('Sending transaction via WalletConnect v2: to=$to, value=$value');
      
      // Send transaction request
      final result = await _web3App!.request(
        topic: _currentSession!.topic,
        chainId: 'eip155:$_chainId',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [
            {
              'from': _walletAddress!,
              'to': to,
              'value': value,
              if (data != null) 'data': data,
            }
          ],
        ),
      );
      
      debugPrint('Transaction sent: $result');
      return result.toString();
    } catch (e) {
      debugPrint('Transaction error: $e');
      rethrow;
    }
  }

  Future<String> signMessage(String message) async {
    if (!_isConnected || _web3App == null || _currentSession == null) {
      throw Exception('Wallet not connected');
    }

    try {
      debugPrint('Signing message via WalletConnect v2: $message');
      
      final signature = await _web3App!.request(
        topic: _currentSession!.topic,
        chainId: 'eip155:$_chainId',
        request: SessionRequestParams(
          method: 'personal_sign',
          params: [message, _walletAddress!],
        ),
      );
      
      debugPrint('Message signed: $signature');
      return signature.toString();
    } catch (e) {
      debugPrint('Sign message error: $e');
      rethrow;
    }
  }

  Future<String> signTypedData(Map<String, dynamic> typedData) async {
    if (!_isConnected || _web3App == null || _currentSession == null) {
      throw Exception('Wallet not connected');
    }

    try {
      debugPrint('Signing typed data via WalletConnect v2: $typedData');
      
      final signature = await _web3App!.request(
        topic: _currentSession!.topic,
        chainId: 'eip155:$_chainId',
        request: SessionRequestParams(
          method: 'eth_signTypedData',
          params: [_walletAddress!, typedData],
        ),
      );
      
      debugPrint('Typed data signed: $signature');
      return signature.toString();
    } catch (e) {
      debugPrint('Sign typed data error: $e');
      rethrow;
    }
  }

  /// Check if the connected wallet is one of the Hardhat test accounts
  bool isHardhatTestAccount() {
    if (_walletAddress == null) return false;
    
    final hardhatAccounts = [
      '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // Customer #1
      '0x70997970C51812dc3A010C7d01b50e0d17dc79C8', // Driver #1
      '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC', // Customer #2
      '0x90F79bf6EB2c4f870365E785982E1f101E93b906', // Driver #2
      '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65', // Customer #3
    ];
    
    return hardhatAccounts.any((addr) => 
      addr.toLowerCase() == _walletAddress!.toLowerCase()
    );
  }

  /// Get the role of the connected Hardhat test account
  String? getHardhatAccountRole() {
    if (!isHardhatTestAccount()) return null;
    
    final addr = _walletAddress!.toLowerCase();
    
    if (addr == '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266' ||
        addr == '0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc' ||
        addr == '0x15d34aaf54267db7d7c367839aaf71a00a2c6a65') {
      return 'Customer';
    } else if (addr == '0x70997970c51812dc3a010c7d01b50e0d17dc79c8' ||
               addr == '0x90f79bf6eb2c4f870365e785982e1f101e93b906') {
      return 'Driver';
    }
    
    return null;
  }

  @override
  void dispose() {
    _web3App?.onSessionConnect.unsubscribe(_onSessionConnect);
    _web3App?.onSessionUpdate.unsubscribe(_onSessionUpdate);
    _web3App?.onSessionDelete.unsubscribe(_onSessionDelete);
    disconnect();
    super.dispose();
  }
}
