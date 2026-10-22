import 'package:flutter/material.dart';

class FarmSelectionScreen extends StatelessWidget {
  const FarmSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Model dataset simulating API response for Farm Cards
    final List<Map<String, dynamic>> farms = [
      {
        'name': 'Green Valley Farm',
        'subtitle': 'Central Greenhouse',
        'status': 'Healthy',
        'statusColor': Colors.green.shade100,
        'statusTextColor': Colors.green.shade800,
      },
      {
        'name': 'Sunrise Hydroponics',
        'subtitle': 'Vertical Farming Unit',
        'status': 'Warning',
        'statusColor': Colors.orange.shade100,
        'statusTextColor': Colors.orange.shade800,
      },
      {
        'name': 'EcoFarm 360',
        'subtitle': 'Outdoor Field',
        'status': 'Critical',
        'statusColor': Colors.red.shade100,
        'statusTextColor': Colors.red.shade800,
      },
      {
        'name': 'Hilltop Greens',
        'subtitle': 'Greenhouse 2',
        'status': 'Healthy',
        'statusColor': Colors.green.shade100,
        'statusTextColor': Colors.green.shade800,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '3. Farm Selection',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Farm',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a farm to continue',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Dynamic List Rendering via ListView.builder
              Expanded(
                child: ListView.builder(
                  itemCount: farms.length,
                  itemBuilder: (context, index) {
                    final farm = farms[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Visual placeholder representing farm thumbnail image
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.green.shade800,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.landscape,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Farm Details Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farm['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    farm['subtitle'],
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Status Tag Component
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: farm['statusColor'],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      farm['status'],
                                      style: TextStyle(
                                        color: farm['statusTextColor'],
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Add Farm Action Button
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Color(0xFF2E7D32), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add New Farm',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}