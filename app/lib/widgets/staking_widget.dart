import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import '../services/blockchain/staking_service.dart';

class StakingWidget extends StatefulWidget {
  final StakingService stakingService;
  final EthereumAddress userAddress;

  const StakingWidget({
    Key? key,
    required this.stakingService,
    required this.userAddress,
  }) : super(key: key);

  @override
  State<StakingWidget> createState() => _StakingWidgetState();
}

class _StakingWidgetState extends State<StakingWidget> {
  final _amountController = TextEditingController();
  final _lockPeriodController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _stakeInfo;
  BigInt? _pendingReward;

  @override
  void initState() {
    super.initState();
    _loadStakeInfo();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _lockPeriodController.dispose();
    super.dispose();
  }

  Future<void> _loadStakeInfo() async {
    setState(() => _isLoading = true);
    try {
      final stakeInfo = await widget.stakingService.getStakeInfo(widget.userAddress);
      final reward = await widget.stakingService.calculateReward(widget.userAddress);
      
      if (mounted) {
        setState(() {
          _stakeInfo = stakeInfo;
          _pendingReward = reward;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stake info: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _stake() async {
    if (_amountController.text.isEmpty || _lockPeriodController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final amount = BigInt.parse(_amountController.text);
      final lockPeriod = BigInt.parse(_lockPeriodController.text);
      
      await widget.stakingService.stake(amount, lockPeriod);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stake submitted successfully')),
        );
        await _loadStakeInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error staking: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unstake() async {
    setState(() => _isLoading = true);
    try {
      await widget.stakingService.unstake();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unstake successful')),
        );
        await _loadStakeInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unstaking: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Staking Dashboard',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_stakeInfo != null) ...[
              Text('Current Stake: ${_stakeInfo!['amount']} tokens'),
              Text('Lock Period: ${_stakeInfo!['lockPeriod']} seconds'),
              Text('Start Time: ${DateTime.fromMillisecondsSinceEpoch(_stakeInfo!['startTime'].toInt() * 1000)}'),
              if (_pendingReward != null)
                Text('Pending Rewards: $_pendingReward tokens'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _unstake,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Unstake'),
                ),
              ),
            ] else ...[
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount to Stake',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lockPeriodController,
                decoration: const InputDecoration(
                  labelText: 'Lock Period (in seconds)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _stake,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Stake'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 