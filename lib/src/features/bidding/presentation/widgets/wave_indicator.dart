import 'package:flutter/material.dart';

class WaveIndicator extends StatelessWidget {
  final int currentWave;
  final bool isSearching;

  const WaveIndicator({
    super.key,
    required this.currentWave,
    this.isSearching = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2b32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF13b6ec).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWaveDot(1, '15 كم', 'القريبون'),
          _buildConnector(),
          _buildWaveDot(2, '50 كم', 'المنطقة'),
          _buildConnector(),
          _buildWaveDot(3, 'الكل', 'الجميع'),
        ],
      ),
    );
  }

  Widget _buildWaveDot(int wave, String distance, String label) {
    final isActive = currentWave == wave;
    final isPast = currentWave > wave;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? const Color(0xFF13b6ec)
                : isPast
                ? const Color(0xFF13b6ec).withValues(alpha: 0.3)
                : Colors.grey[800],
            border: isActive ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: isActive && isSearching
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Icon(
                  isPast ? Icons.check : Icons.radio_button_unchecked,
                  color: isActive || isPast ? Colors.white : Colors.grey,
                  size: 20,
                ),
        ),
        const SizedBox(height: 4),
        Text(
          distance,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ],
    );
  }

  Widget _buildConnector() {
    return Container(
      width: 30,
      height: 2,
      color: Colors.grey[800],
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
