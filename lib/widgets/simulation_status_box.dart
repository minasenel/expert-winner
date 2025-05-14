import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

enum SimulationStatus {
  notReady,
  pending,
  ready,
}

class SimulationStatusBox extends StatelessWidget {
  final VoidCallback? onTap;

  const SimulationStatusBox({
    Key? key,
    this.onTap,
  }) : super(key: key);

  Future<SimulationStatus> _getUserSimulationStatus() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return SimulationStatus.notReady;

    try {
      final response = await http.get(
        Uri.parse('https://pubccvzpnlgklhugfswc.supabase.co/functions/v1/rapid-processor'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        print('Unauthorized: User not authenticated');
        return SimulationStatus.notReady;
      }

      if (response.statusCode != 200) {
        print('Error fetching status: ${response.statusCode}');
        return SimulationStatus.notReady;
      }

      final data = json.decode(response.body);
      final status = data['status'] as String;

      switch (status) {
        case 'not-ready':
          return SimulationStatus.notReady;
        case 'pending':
          return SimulationStatus.pending;
        case 'ready':
          return SimulationStatus.ready;
        default:
          print('Unknown status: $status');
          return SimulationStatus.notReady;
      }
    } catch (e) {
      print('Error fetching simulation status: $e');
      return SimulationStatus.notReady;
    }
  }

  Color _getStatusColor(SimulationStatus status) {
    switch (status) {
      case SimulationStatus.notReady:
        return const Color(0xFF2196F3); // Blue
      case SimulationStatus.pending:
        return const Color(0xFFFFC107); // Yellow
      case SimulationStatus.ready:
        return const Color(0xFF4CAF50); // Green
    }
  }

  String _getStatusMessage(SimulationStatus status) {
    switch (status) {
      case SimulationStatus.notReady:
        return "No photos uploaded yet. Try the nose simulation!";
      case SimulationStatus.pending:
        return "Simulation in progress";
      case SimulationStatus.ready:
        return "Simulation ready! Tap to view";
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SimulationStatus>(
      future: _getUserSimulationStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data!;
        final color = _getStatusColor(status);
        final message = _getStatusMessage(status);

        Widget statusBox = Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        );

        if (status == SimulationStatus.ready && onTap != null) {
          statusBox = GestureDetector(
            onTap: onTap,
            child: statusBox,
          );
        }

        return statusBox;
      },
    );
  }
} 