import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import '../services/blockchain/rating_service.dart';

class RatingWidget extends StatefulWidget {
  final EthereumAddress userAddress;
  final RatingService ratingService;
  final Function()? onRatingSubmitted;

  const RatingWidget({
    Key? key,
    required this.userAddress,
    required this.ratingService,
    this.onRatingSubmitted,
  }) : super(key: key);

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  double _rating = 0;
  final _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.ratingService.submitRating(
        widget.userAddress,
        BigInt.from(_rating),
        _commentController.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted successfully')),
        );
        widget.onRatingSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting rating: $e')),
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
              'Rate User',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _rating = index + 1.0),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit Rating'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 