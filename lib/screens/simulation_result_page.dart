import 'package:flutter/material.dart';

class SimulationResultPage extends StatelessWidget {
  const SimulationResultPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Simulation Results',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F5F5),
              Color(0xFFE8E6E1),
            ],
          ),
        ),
        child: const Center(
          child: Text(
            'Simulation results will be displayed here',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF2C2C2C),
            ),
          ),
        ),
      ),
    );
  }
} 