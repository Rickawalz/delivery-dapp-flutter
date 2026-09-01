import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseStatusWidget extends StatefulWidget {
  const FirebaseStatusWidget({super.key});

  @override
  State<FirebaseStatusWidget> createState() => _FirebaseStatusWidgetState();
}

class _FirebaseStatusWidgetState extends State<FirebaseStatusWidget> {
  bool _isConnected = false;
  String _status = 'Checking...';
  String _lastTest = 'Never';

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      setState(() {
        _status = 'Testing connection...';
      });

      final firestore = FirebaseFirestore.instance;
      
      // Test write
      await firestore.collection('status').doc('test').set({
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'online',
        'test': DateTime.now().toIso8601String(),
      });

      // Test read
      final doc = await firestore.collection('status').doc('test').get();
      
      if (doc.exists) {
        setState(() {
          _isConnected = true;
          _status = 'Connected ✅';
          _lastTest = DateTime.now().toString().substring(11, 19);
        });
        
        // Clean up
        await firestore.collection('status').doc('test').delete();
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _status = 'Failed ❌: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Firebase Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _testConnection,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Status: $_status'),
            Text('Last Test: $_lastTest'),
            if (_isConnected)
              const Text(
                'Database is working correctly!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
