import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/delivery/delivery_service.dart';
import '../../services/blockchain/walletconnect_service.dart';
import '../../utils/rel_utils.dart';
import '../common/transaction_status_widget.dart';

/// A multi-step dialog widget for creating new delivery requests.
/// 
/// This dialog guides users through a 3-step process:
/// 1. Delivery Details - Basic information like receiver, description, and value
/// 2. Location Information - Pickup and delivery addresses with time preferences
/// 3. Review & Confirmation - Final review before submission
/// 
/// The dialog includes form validation, loading states, and error handling
/// to provide a smooth user experience during delivery creation.
class CreateDeliveryDialog extends StatefulWidget {
  /// Creates a new CreateDeliveryDialog widget.
  const CreateDeliveryDialog({super.key});

  @override
  State<CreateDeliveryDialog> createState() => _CreateDeliveryDialogState();
}

class _CreateDeliveryDialogState extends State<CreateDeliveryDialog> {
  /// Form key for validating form inputs across all steps
  final _formKey = GlobalKey<FormState>();
  
  /// Page controller for managing the multi-step navigation
  final _pageController = PageController();
  
  /// Current step in the multi-step process (0-2)
  int _currentStep = 0;
  
  /// Loading state to prevent multiple submissions and show progress
  bool _isCreatingDelivery = false;
  
  // === FORM DATA FIELDS ===
  
  /// Ethereum address of the driver (validated format: 0x...)
  String _driverAddress = '';
  
  /// Description of the delivery item(s)
  String _description = '';
  
  /// Distance of the delivery in kilometers (converted to meters for contract)
  double _distanceKm = 0.0;
  
  /// Payment amount in USD (converted to cents for contract)
  double _fiatAmountUSD = 0.0;
  
  /// Optional preferred delivery time (user can select date and time)
  DateTime? _preferredDeliveryTime;
  
  /// Type of delivery service (Standard, Express, Same Day)
  String _deliveryType = 'Standard';
  
  /// Whether this is an urgent delivery (affects priority)
  bool _isUrgent = false;

  // === STATIC DATA ===
  
  /// Available delivery type options with different service levels
  final List<String> _deliveryTypes = ['Standard', 'Express', 'Same Day'];

  @override
  Widget build(BuildContext context) {
    /// Main dialog structure with header, progress indicator, content, and navigation
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Create New Delivery',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: _isCreatingDelivery ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Progress indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildStepIndicator(0, 'Details'),
                  Expanded(child: _buildStepLine(0)),
                  _buildStepIndicator(1, 'Location'),
                  Expanded(child: _buildStepLine(1)),
                  _buildStepIndicator(2, 'Review'),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentStep = index;
                      });
                    },
                    children: [
                      _buildDetailsStep(),
                      _buildLocationStep(),
                      _buildReviewStep(),
                    ],
                  ),
                  if (_isCreatingDelivery)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Creating your delivery...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isCreatingDelivery ? null : _previousStep,
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCreatingDelivery 
                          ? null 
                          : (_currentStep == 2 ? _createDelivery : _nextStep),
                      child: _isCreatingDelivery
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_currentStep == 2 ? 'Create Delivery' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  /// Builds a step indicator showing the current progress through the multi-step form.
  /// 
  /// The indicator shows:
  /// - Active step: Blue background with step number
  /// - Completed steps: Blue background with checkmark
  /// - Future steps: Gray background with step number
  /// 
  /// [step] The step number (0-2)
  /// [label] The label to display below the indicator
  Widget _buildStepIndicator(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;
    
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? Colors.blue[600] : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.blue[600] : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Builds a connecting line between step indicators.
  /// 
  /// Shows blue for completed connections and gray for pending ones.
  /// 
  /// [step] The step number to determine if connection should be active
  Widget _buildStepLine(int step) {
    return Container(
      height: 2,
      color: step < _currentStep ? Colors.blue[600] : Colors.grey[300],
    );
  }

  /// Builds the first step of the form containing basic delivery details.
  /// 
  /// This step includes:
  /// - Receiver address (Ethereum address validation)
  /// - Description (required text field)
  /// - Value in ETH (numeric validation)
  /// - Delivery type selection (dropdown)
  /// - Urgent delivery option (checkbox)
  /// 
  /// All fields are validated before allowing progression to next step.
  Widget _buildDetailsStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Driver Address
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Driver Address',
                  hintText: '0x...',
                  prefixIcon: Icon(Icons.local_shipping),
                  border: OutlineInputBorder(),
                  helperText: 'Enter a valid Ethereum address (42 characters starting with 0x)',
                ),
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  // Convert to lowercase for consistency
                  FilteringTextInputFormatter.allow(RegExp(r'[a-fA-F0-9x]')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a receiver address';
                  }
                  
                  final trimmedValue = value.trim();
                  
                  // Check basic format
                  if (!trimmedValue.startsWith('0x')) {
                    return 'Address must start with 0x';
                  }
                  
                  if (trimmedValue.length != 42) {
                    return 'Address must be exactly 42 characters';
                  }
                  
                  // Check if it's a valid hex string
                  if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(trimmedValue)) {
                    return 'Please enter a valid Ethereum address format';
                  }
                  
                  // Check for common invalid addresses
                  if (trimmedValue == '0x0000000000000000000000000000000000000000') {
                    return 'Cannot use zero address';
                  }
                  
                  return null;
                },
                onSaved: (value) => _driverAddress = value!.trim(),
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter delivery description',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  helperText: 'Describe what is being delivered (min 10 characters)',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  
                  final trimmedValue = value.trim();
                  
                  if (trimmedValue.length < 10) {
                    return 'Description must be at least 10 characters long';
                  }
                  
                  if (trimmedValue.length > 500) {
                    return 'Description cannot exceed 500 characters';
                  }
                  
                  // Check for suspicious content (basic profanity/spam detection)
                  final suspiciousWords = ['spam', 'test', 'fake', 'dummy'];
                  final lowerValue = trimmedValue.toLowerCase();
                  if (suspiciousWords.any((word) => lowerValue.contains(word))) {
                    return 'Please provide a meaningful description';
                  }
                  
                  return null;
                },
                onSaved: (value) => _description = value!.trim(),
              ),
              const SizedBox(height: 16),
              
              // Distance
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Distance (km)',
                  hintText: '5.0',
                  prefixIcon: Icon(Icons.social_distance),
                  border: OutlineInputBorder(),
                  helperText: 'Minimum: 0.5 km, Maximum: 1000 km',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  FilteringTextInputFormatter.deny(RegExp(r'\.{2,}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter distance';
                  }
                  
                  final number = double.tryParse(value.trim());
                  
                  if (number == null) {
                    return 'Please enter a valid number';
                  }
                  
                  if (number < 0.5) {
                    return 'Minimum distance is 0.5 km';
                  }
                  
                  if (number > 1000) {
                    return 'Maximum distance is 1000 km';
                  }
                  
                  return null;
                },
                onSaved: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    _distanceKm = double.parse(value.trim());
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Fiat Amount
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Payment Amount (USD)',
                  hintText: '10.00',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                  helperText: 'Minimum: \$1.00, Maximum: \$10,000',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  FilteringTextInputFormatter.deny(RegExp(r'\.{2,}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter payment amount';
                  }
                  
                  final number = double.tryParse(value.trim());
                  
                  if (number == null) {
                    return 'Please enter a valid number';
                  }
                  
                  if (number < 1.0) {
                    return 'Minimum amount is \$1.00';
                  }
                  
                  if (number > 10000) {
                    return 'Maximum amount is \$10,000';
                  }
                  
                  return null;
                },
                onSaved: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    _fiatAmountUSD = double.parse(value.trim());
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Delivery Type
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Delivery Type',
                  prefixIcon: Icon(Icons.local_shipping),
                  border: OutlineInputBorder(),
                ),
                value: _deliveryType,
                items: _deliveryTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _deliveryType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Urgent checkbox
              CheckboxListTile(
                title: const Text('Urgent Delivery'),
                subtitle: const Text('Higher priority, faster processing'),
                value: _isUrgent,
                onChanged: (value) {
                  setState(() {
                    _isUrgent = value!;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the second step containing timing information.
  /// 
  /// This step includes:
  /// - Preferred delivery time (optional date/time picker)
  Widget _buildLocationStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            'Additional Options',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Preferred delivery time
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Preferred Delivery Time'),
            subtitle: Text(_preferredDeliveryTime != null 
                ? DateFormat('MMM dd, yyyy HH:mm').format(_preferredDeliveryTime!)
                : 'Not specified'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (date != null) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _preferredDeliveryTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              }
            },
          ),
        ],
        ),
      ),
    );
  }

  /// Builds the final review step showing all entered information.
  /// 
  /// Displays a summary of:
  /// - All form fields from previous steps
  /// - Formatted values (dates, addresses, etc.)
  /// - Read-only confirmation before submission
  /// 
  /// Users can review all details before creating the delivery.
  Widget _buildReviewStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Your Delivery',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReviewItem('Driver', _driverAddress),
                    _buildReviewItem('Description', _description),
                    _buildReviewItem('Distance', '${_distanceKm} km'),
                    _buildReviewItem('Amount', '\$${_fiatAmountUSD.toStringAsFixed(2)}'),
                    _buildReviewItem('Type', _deliveryType),
                    _buildReviewItem('Urgent', _isUrgent ? 'Yes' : 'No'),
                    if (_preferredDeliveryTime != null)
                      _buildReviewItem('Preferred Time', 
                          DateFormat('MMM dd, yyyy HH:mm').format(_preferredDeliveryTime!)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single review item showing a label-value pair.
  /// 
  /// Used in the review step to display form data in a consistent format.
  /// 
  /// [label] The field label (e.g., "Receiver", "Description")
  /// [value] The field value to display
  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  /// Advances to the next step in the multi-step form.
  /// 
  /// For the first step (details), validates the form before proceeding.
  /// For the location step, validates location fields before proceeding.
  /// For the review step, proceeds to delivery creation.
  /// 
  /// Uses animated page transitions for smooth user experience.
  void _nextStep() {
    if (_currentStep == 0) {
      // Validate form on first step before proceeding
      if (_formKey.currentState!.validate()) {
        _formKey.currentState!.save();
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (_currentStep == 1) {
      // Validate location fields on second step
      if (_validateLocationFields()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Review step - proceed to delivery creation
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Validates location fields and shows appropriate error messages.
  /// 
  /// Returns true if validation passes, false otherwise.
  bool _validateLocationFields() {
    // Validate distance
    if (_distanceKm <= 0) {
      _showValidationError('Please enter a valid distance');
      return false;
    }
    
    if (_distanceKm < 0.5) {
      _showValidationError('Distance must be at least 0.5 km');
      return false;
    }
    
    // Validate fiat amount
    if (_fiatAmountUSD <= 0) {
      _showValidationError('Please enter a valid payment amount');
      return false;
    }
    
    if (_fiatAmountUSD < 1.0) {
      _showValidationError('Payment must be at least \$1.00');
      return false;
    }
    
    return true;
  }

  /// Shows a validation error message to the user.
  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Returns to the previous step in the multi-step form.
  /// 
  /// Uses animated page transitions for smooth user experience.
  void _previousStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Creates a new delivery with the collected form data.
  /// 
  /// This method handles the complete delivery creation workflow:
  /// 1. Validates the form one final time
  /// 2. Saves form data to local variables
  /// 3. Sets loading state to prevent multiple submissions
  /// 4. Calls the DeliveryService to create the delivery
  /// 5. Handles success/error scenarios with appropriate user feedback
  /// 6. Manages loading state and dialog lifecycle
  /// 
  /// Error handling includes:
  /// - Network/blockchain errors during creation
  /// - Null response from service
  /// - Widget disposal during async operation
  /// - Retry functionality for failed attempts
  void _createDelivery() async {
    print('\n╔════════════════════════════════════════╗');
    print('║  CREATE DELIVERY DIALOG - START        ║');
    print('╚════════════════════════════════════════╝');
    
    print('📋 Form data:');
    print('  - Driver address: $_driverAddress');
    print('  - Description: $_description');
    print('  - Distance (km): $_distanceKm');
    print('  - Fiat amount (USD): $_fiatAmountUSD');

    // Check if wallet is connected first
    final walletConnectService = context.read<WalletConnectService>();
    print('\n🔐 Wallet service check:');
    print('  - Is connected: ${walletConnectService.isConnected}');
    
    if (!walletConnectService.isConnected) {
      print('❌ Wallet not connected, showing error dialog');
      // Show error dialog instead of SnackBar to ensure it appears in front
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Wallet Not Connected'),
            ],
          ),
          content: const Text(
            'Please connect your wallet first to create a delivery.\n\nYou can connect your wallet using the wallet connection section on the main screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close error dialog
                Navigator.pop(context); // Close create delivery dialog
                // The user will need to connect wallet from main screen
              },
              child: const Text('Connect Wallet'),
            ),
          ],
        ),
      );
      return;
    }

    print('\n⏳ Setting loading state...');
    setState(() {
      _isCreatingDelivery = true;
    });
    
    try {
      print('\n📞 Calling DeliveryService.createDelivery...');
      print('  - Parameters:');
      print('    • Driver: $_driverAddress');
      print('    • Distance: ${(_distanceKm * 1000).toInt()} meters');
      print('    • Amount: \$$_fiatAmountUSD');
      
      // Show transaction status dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Processing Transaction'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Please wait while your transaction is being confirmed on the blockchain...'),
                  const SizedBox(height: 16),
                  Consumer<DeliveryService>(
                    builder: (context, deliveryService, _) {
                      final txHash = deliveryService.lastTransactionHash;
                      if (txHash != null) {
                        return TransactionStatusWidget(
                          txHash: txHash,
                          showDetails: true,
                        );
                      }
                      return const Text('Submitting transaction...');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }
      
      final delivery = await context.read<DeliveryService>().createDelivery(
        driverAddress: _driverAddress,
        description: _description,
        distanceMeters: (_distanceKm * 1000).toInt(),
        fiatAmountUSD: _fiatAmountUSD,
      );

      print('\n📦 Delivery result: ${delivery != null ? "SUCCESS" : "NULL"}');

      if (mounted) {
        // Close transaction status dialog
        Navigator.pop(context);
        
        print('🚪 Closing create dialog...');
        Navigator.pop(context);
        
        if (delivery != null) {
          print('✅ Showing success message');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery created successfully! 🚚'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          print('⚠️  Showing null delivery warning');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create delivery. Please try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
      print('\n╔════════════════════════════════════════╗');
      print('║  CREATE DELIVERY DIALOG - SUCCESS      ║');
      print('╚════════════════════════════════════════╝\n');
      
    } catch (e, stackTrace) {
      print('\n╔════════════════════════════════════════╗');
      print('║  CREATE DELIVERY DIALOG - ERROR        ║');
      print('╚════════════════════════════════════════╝');
      print('Error: $e');
      print('Stack trace:\n$stackTrace');
      print('════════════════════════════════════════\n');
      
      if (mounted) {
        // Close transaction status dialog if it's open
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        
        setState(() {
          _isCreatingDelivery = false;
        });
        
        // Show error message with details
        final errorMessage = e.toString();
        String userFriendlyMessage = 'Failed to create delivery';
        
        if (errorMessage.contains('timeout')) {
          userFriendlyMessage = 'Transaction timeout. The transaction may still be pending. Please check your wallet.';
        } else if (errorMessage.contains('reverted')) {
          userFriendlyMessage = 'Transaction was rejected by the blockchain. Please check your inputs and try again.';
        } else if (errorMessage.contains('MetaMask')) {
          userFriendlyMessage = 'MetaMask error. Please check your wallet connection.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userFriendlyMessage),
                const SizedBox(height: 4),
                Text(
                  'Error: ${e.toString()}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _createDelivery,
            ),
          ),
        );
      }
    }
  }
}
