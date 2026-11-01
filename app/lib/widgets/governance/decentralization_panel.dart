import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/blockchain/contract_service.dart';

class DecentralizationPanel extends StatefulWidget {
  const DecentralizationPanel({super.key});

  @override
  State<DecentralizationPanel> createState() => _DecentralizationPanelState();
}

class _DecentralizationPanelState extends State<DecentralizationPanel> {
  bool _loading = true;
  bool _advancing = false;
  String? _error;
  String? _actionMessage;
  String? _phase;
  String? _controller;
  PhaseProgress? _progress;
  PhaseMilestones? _milestones;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contracts = context.read<ContractService>();
      final phase = await contracts.getPhaseInfo();
      final controller = await contracts.currentController();
      final progress = await contracts.getProgress();
      final milestones = await contracts.getCurrentMilestones();
      if (!mounted) return;
      setState(() {
        _phase = phase;
        _controller = controller;
        _progress = progress;
        _milestones = milestones;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _advance() async {
    setState(() {
      _advancing = true;
      _actionMessage = null;
    });
    try {
      final txHash = await context.read<ContractService>().advancePhase();
      if (!mounted) return;
      setState(() {
        _advancing = false;
        _actionMessage = 'Phase advanced. Transaction $txHash';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _advancing = false;
        _actionMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 12),
        Text(
          'DecentralizationPhase is not reachable. $_error',
          style: TextStyle(color: Colors.red[800]),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final progress = _progress!;
    final milestones = _milestones!;
    final nextPhase = progress.phase == 'Bootstrap'
        ? 'Hybrid'
        : progress.phase == 'Hybrid'
            ? 'FullDAO'
            : 'none';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 8),
        Text('Current phase: ${_phase ?? progress.phase}'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text('Controller: ${_shortAddress(_controller ?? '')}'),
            ),
            IconButton(
              tooltip: 'Copy controller address',
              onPressed: _controller == null
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: _controller!));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Controller address copied')),
                      );
                    },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        _progressRow('Deliveries', progress.deliveryPercent),
        _progressRow('Drivers', progress.driverPercent),
        _progressRow('Time', progress.timePercent),
        const SizedBox(height: 8),
        Text('Stability: ${progress.stabilityDays} days'),
        const SizedBox(height: 12),
        Text(
          nextPhase == 'none'
              ? 'Already at FullDAO. There is no next phase.'
              : 'Milestones for $nextPhase',
        ),
        Text('Deliveries: ${milestones.requiredDeliveries}'),
        Text('Drivers: ${milestones.requiredDrivers}'),
        Text('Days: ${milestones.requiredDays}'),
        Text('Stability days: ${milestones.requiredStabilityDays}'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: progress.canAdvance && !_advancing ? _advance : null,
          child: Text(_advancing ? 'Advancing...' : 'Advance phase'),
        ),
        if (_actionMessage != null) ...[
          const SizedBox(height: 8),
          Text(_actionMessage!),
        ],
        const SizedBox(height: 12),
        const Text(
          'Proposals and voting are done through the RLE Governor; a voting interface is not included in this prototype.',
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Decentralization',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading || _advancing ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _progressRow(String label, int percent) {
    final clamped = percent < 0 ? 0.0 : (percent > 100 ? 1.0 : percent / 100);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $percent%'),
          LinearProgressIndicator(value: clamped),
        ],
      ),
    );
  }

  String _shortAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
