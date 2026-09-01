import 'dart:math';

/// Utility class for REL token conversions and formatting
class RelUtils {
  /// Default decimals for REL token (18)
  static const int defaultDecimals = 18;
  
  /// Parse REL string to wei BigInt with precise decimal handling
  /// 
  /// [relStr] - REL amount as string (e.g., "1.5", "0.001")
  /// [decimals] - Token decimals (default 18)
  /// 
  /// Returns BigInt representing the amount in wei
  static BigInt parseRelToWei(String relStr, {int decimals = defaultDecimals}) {
    if (relStr.isEmpty) return BigInt.zero;
    
    final parts = relStr.split('.');
    final wholePart = parts[0].isEmpty ? '0' : parts[0];
    final fracPart = parts.length == 2 ? parts[1] : '0';
    
    // Parse whole part
    final whole = BigInt.parse(wholePart);
    
    // Parse fractional part with proper padding
    final paddedFrac = fracPart.padRight(decimals, '0').substring(0, decimals);
    final frac = BigInt.parse(paddedFrac);
    
    return whole * BigInt.from(10).pow(decimals) + frac;
  }
  
  /// Format wei BigInt to REL string with specified decimal places
  /// 
  /// [wei] - Amount in wei as BigInt
  /// [decimals] - Token decimals (default 18)
  /// [displayDecimals] - Number of decimal places to show (default 6)
  /// 
  /// Returns formatted REL string (e.g., "1.5 REL")
  static String formatWeiToRel(BigInt wei, {int decimals = defaultDecimals, int displayDecimals = 6}) {
    final base = BigInt.from(10).pow(decimals);
    final whole = wei ~/ base;
    final frac = wei % base;
    
    if (frac == BigInt.zero) {
      return whole.toString();
    }
    
    // Convert fractional part to string with proper padding
    final fracStr = frac.toString().padLeft(decimals, '0');
    final trimmedFrac = fracStr.substring(0, min(displayDecimals, fracStr.length));
    
    // Remove trailing zeros
    final cleanFrac = trimmedFrac.replaceFirst(RegExp(r'0+$'), '');
    
    return cleanFrac.isEmpty ? whole.toString() : '$whole.$cleanFrac';
  }
  
  /// Format REL amount for display with symbol
  /// 
  /// [wei] - Amount in wei as BigInt
  /// [symbol] - Token symbol (default "REL")
  /// [decimals] - Token decimals (default 18)
  /// [displayDecimals] - Number of decimal places to show (default 6)
  /// 
  /// Returns formatted string (e.g., "1.5 REL")
  static String formatRelDisplay(BigInt wei, {String symbol = 'REL', int decimals = defaultDecimals, int displayDecimals = 6}) {
    final amount = formatWeiToRel(wei, decimals: decimals, displayDecimals: displayDecimals);
    return '$amount $symbol';
  }
  
  /// Convert double to wei (for backward compatibility)
  /// 
  /// [relAmount] - REL amount as double
  /// [decimals] - Token decimals (default 18)
  /// 
  /// Returns BigInt representing the amount in wei
  static BigInt doubleToWei(double relAmount, {int decimals = defaultDecimals}) {
    final multiplier = pow(10, decimals);
    return BigInt.from((relAmount * multiplier).round());
  }
  
  /// Convert wei to double (for backward compatibility)
  /// 
  /// [wei] - Amount in wei as BigInt
  /// [decimals] - Token decimals (default 18)
  /// 
  /// Returns double representing the REL amount
  static double weiToDouble(BigInt wei, {int decimals = defaultDecimals}) {
    final divisor = pow(10, decimals);
    return wei.toDouble() / divisor;
  }
  
  /// Validate REL amount string format
  /// 
  /// [relStr] - REL amount as string
  /// 
  /// Returns true if valid format, false otherwise
  static bool isValidRelAmount(String relStr) {
    if (relStr.isEmpty) return false;
    
    // Check for valid decimal format
    final regex = RegExp(r'^\d+(\.\d+)?$');
    if (!regex.hasMatch(relStr)) return false;
    
    // Check for reasonable decimal places
    final parts = relStr.split('.');
    if (parts.length == 2 && parts[1].length > defaultDecimals) {
      return false;
    }
    
    // Check for reasonable value range
    final amount = double.tryParse(relStr);
    if (amount == null || amount < 0 || amount > 1000000) {
      return false;
    }
    
    return true;
  }
  
  /// Get minimum REL amount for transactions
  /// 
  /// Returns minimum REL amount in wei
  static BigInt getMinimumRelAmount({int decimals = defaultDecimals}) {
    return BigInt.from(10).pow(decimals - 3); // 0.001 REL
  }
  
  /// Get maximum REL amount for transactions
  /// 
  /// Returns maximum REL amount in wei
  static BigInt getMaximumRelAmount({int decimals = defaultDecimals}) {
    return BigInt.from(10).pow(decimals + 6); // 1,000,000 REL
  }
}
