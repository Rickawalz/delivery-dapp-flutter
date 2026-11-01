import 'dart:math';

/// Utility class for RLE token conversions and formatting
class RleUtils {
  /// Default decimals for RLE token (18)
  static const int defaultDecimals = 18;
  
  /// Parse RLE string to wei BigInt with precise decimal handling
  /// 
  /// [rleStr] - RLE amount as string (e.g., "1.5", "0.001")
  /// [decimals] - Token decimals (default 18)
  /// 
  /// Returns BigInt representing the amount in wei
  static BigInt parseRleToWei(String rleStr, {int decimals = defaultDecimals}) {
    if (rleStr.isEmpty) return BigInt.zero;
    
    final parts = rleStr.split('.');
    final wholePart = parts[0].isEmpty ? '0' : parts[0];
    final fracPart = parts.length == 2 ? parts[1] : '0';
    
    // Parse whole part
    final whole = BigInt.parse(wholePart);
    
    // Parse fractional part with proper padding
    final paddedFrac = fracPart.padRight(decimals, '0').substring(0, decimals);
    final frac = BigInt.parse(paddedFrac);
    
    return whole * BigInt.from(10).pow(decimals) + frac;
  }
  
  /// Format wei BigInt to RLE string with specified decimal places
  /// 
  /// [wei] - Amount in wei as BigInt
  /// [decimals] - Token decimals (default 18)
  /// [displayDecimals] - Number of decimal places to show (default 6)
  /// 
  /// Returns formatted RLE string (e.g., "1.5 RLE")
  static String formatWeiToRle(BigInt wei, {int decimals = defaultDecimals, int displayDecimals = 6}) {
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
  
  /// Format RLE amount for display with symbol
  /// 
  /// [wei] - Amount in wei as BigInt
  /// [symbol] - Token symbol (default "RLE")
  /// [decimals] - Token decimals (default 18)
  /// [displayDecimals] - Number of decimal places to show (default 6)
  /// 
  /// Returns formatted string (e.g., "1.5 RLE")
  static String formatRleDisplay(BigInt wei, {String symbol = 'RLE', int decimals = defaultDecimals, int displayDecimals = 6}) {
    final amount = formatWeiToRle(wei, decimals: decimals, displayDecimals: displayDecimals);
    return '$amount $symbol';
  }
  
  /// Convert double to wei (for backward compatibility)
  /// 
  /// [rleAmount] - RLE amount as double
  /// [decimals] - Token decimals (default 18)
  /// 
  /// Returns BigInt representing the amount in wei
  static BigInt doubleToWei(double rleAmount, {int decimals = defaultDecimals}) {
    final multiplier = pow(10, decimals);
    return BigInt.from((rleAmount * multiplier).round());
  }
  
  /// Convert wei to double (for backward compatibility)
  /// 
  /// [wei] - Amount in wei as BigInt
  /// [decimals] - Token decimals (default 18)
  /// 
  /// Returns double representing the RLE amount
  static double weiToDouble(BigInt wei, {int decimals = defaultDecimals}) {
    final divisor = pow(10, decimals);
    return wei.toDouble() / divisor;
  }
  
  /// Validate RLE amount string format
  /// 
  /// [rleStr] - RLE amount as string
  /// 
  /// Returns true if valid format, false otherwise
  static bool isValidRleAmount(String rleStr) {
    if (rleStr.isEmpty) return false;
    
    // Check for valid decimal format
    final regex = RegExp(r'^\d+(\.\d+)?$');
    if (!regex.hasMatch(rleStr)) return false;
    
    // Check for reasonable decimal places
    final parts = rleStr.split('.');
    if (parts.length == 2 && parts[1].length > defaultDecimals) {
      return false;
    }
    
    // Check for reasonable value range
    final amount = double.tryParse(rleStr);
    if (amount == null || amount < 0 || amount > 1000000) {
      return false;
    }
    
    return true;
  }
  
  /// Get minimum RLE amount for transactions
  /// 
  /// Returns minimum RLE amount in wei
  static BigInt getMinimumRleAmount({int decimals = defaultDecimals}) {
    return BigInt.from(10).pow(decimals - 3); // 0.001 RLE
  }
  
  /// Get maximum RLE amount for transactions
  /// 
  /// Returns maximum RLE amount in wei
  static BigInt getMaximumRleAmount({int decimals = defaultDecimals}) {
    return BigInt.from(10).pow(decimals + 6); // 1,000,000 RLE
  }
}
