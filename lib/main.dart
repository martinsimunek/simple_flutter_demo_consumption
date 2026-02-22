import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotřeba Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SpotrebaHomePage(title: 'Spotřeba App', storage: FileStorage()),
    );
  }
}

class SpotrebaHomePage extends StatefulWidget {
  const SpotrebaHomePage({super.key, required this.title, required this.storage});

  final FileStorage storage;

  final String title;

  @override
  State<SpotrebaHomePage> createState() => _SpotrebaHomePageState();
}

/// Immutable record for fuel fill-up data
class ZaznamOTankovani {
  final double mnozstviPaliva;
  final int stavTachometru;

  const ZaznamOTankovani({
    required this.mnozstviPaliva,
    required this.stavTachometru,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'mnozstviPaliva': mnozstviPaliva,
      'stavTachometru': stavTachometru,
    };
  }

  /// Create from JSON
  factory ZaznamOTankovani.fromJson(Map<String, dynamic> json) {
    return ZaznamOTankovani(
      mnozstviPaliva: (json['mnozstviPaliva'] as num).toDouble(),
      stavTachometru: json['stavTachometru'] as int,
    );
  }

  @override
  String toString() =>
      'ZaznamOTankovani($mnozstviPaliva l, $stavTachometru km)';
}

class FileStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/data.txt');
  }

  Future<String> readFile() async {
      final file = await _localFile;
      final contents = await file.readAsString();
      return contents;
  }

  Future<File> writeFile(String content) async {
    final file = await _localFile;
    return file.writeAsString(content);
  }
}

class _SpotrebaHomePageState extends State<SpotrebaHomePage> {
  late List<ZaznamOTankovani> _seznam = [];

  final TextEditingController _mnozstviPalivaController =
      TextEditingController();
  final TextEditingController _stavTachometruController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final value = await widget.storage.readFile();
      _loadData(value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soubor nenalezen, začínáme s prázdnou databází.')),
      );
    }
  }

  /// Load records from persistent storage
  Future<void> _loadData(String jsonString) async {
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      setState(() {
        _seznam = decoded
            .map((item) => ZaznamOTankovani.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      _showErrorDialog('Chyba čtení ze souboru', 'Nepodařilo se načíst data ze souboru: $e');
    }
  }

  /// Save records to persistent storage
  Future<void> _saveData() async {
    final jsonString = jsonEncode(_seznam.map((z) => z.toJson()).toList());
    widget.storage.writeFile(jsonString);
  }

  /// Validate and add a new record
  void _pridejZaznam() {
    final mnozstviText = _mnozstviPalivaController.text.trim();
    final stavTachometruText = _stavTachometruController.text.trim();

    // Validation
    if (mnozstviText.isEmpty || stavTachometruText.isEmpty) {
      _showErrorDialog('Chyba', 'Prosím vyplňte všechna pole.');
      return;
    }

    try {
      final double mnozstviPaliva = double.parse(mnozstviText);
      final int stavTachometru = int.parse(stavTachometruText);

      if (mnozstviPaliva <= 0) {
        _showErrorDialog('Chyba', 'Množství paliva musí být větší než 0.');
        return;
      }

      if (stavTachometru < 0) {
        _showErrorDialog('Chyba', 'Stav tachometru nemůže být záporný.');
        return;
      }

      // Check if odometer is increasing
      if (_seznam.isNotEmpty && stavTachometru <= _seznam.last.stavTachometru) {
        _showErrorDialog(
          'Chyba',
          'Stav tachometru musí být vyšší než poslední záznam (${_seznam.last.stavTachometru} km).',
        );
        return;
      }

      setState(() {
        _seznam.add(ZaznamOTankovani(
          mnozstviPaliva: mnozstviPaliva,
          stavTachometru: stavTachometru,
        ));
      });

      _saveData();
      _mnozstviPalivaController.clear();
      _stavTachometruController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Záznam přidán')),
      );
    } catch (e) {
      _showErrorDialog('Chyba', 'Prosím zadejte platná čísla.');
    }
  }

  /// Delete a record
  void _deleteZaznam(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrzení smazání'),
        content: const Text('Opravdu chcete smazat tento záznam?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _seznam.removeAt(index);
              });
              _saveData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Záznam smazán')),
              );
            },
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Calculate fuel consumption (l/100km) between two records
  double? _calculateConsumption(int from, int to) {
    if (to <= from || from < 0 || to >= _seznam.length) return null;
    final distance = _seznam[to].stavTachometru - _seznam[from].stavTachometru;
    final fuel = _seznam[to].mnozstviPaliva;
    if (distance == 0) return null;
    return (fuel / distance) * 100;
  }

  /// Calculate average consumption
  double? _getAverageConsumption() {
    if (_seznam.length < 2) return null;
    double totalConsumption = 0;
    int count = 0;
    for (int i = 1; i < _seznam.length; i++) {
      final consumption = _calculateConsumption(i - 1, i);
      if (consumption != null) {
        totalConsumption += consumption;
        count++;
      }
    }
    return count > 0 ? totalConsumption / count : null;
  }

  /// Get total distance traveled
  int? _getTotalDistance() {
    if (_seznam.length < 2) return null;
    return _seznam.last.stavTachometru - _seznam.first.stavTachometru;
  }

  /// Get total fuel used
  double? _getTotalFuel() {
    if (_seznam.isEmpty) return null;
    return _seznam.fold<double>(0, (sum, record) => sum + record.mnozstviPaliva);
  }

  @override
  Widget build(BuildContext context) {
    final avgConsumption = _getAverageConsumption();
    final totalDistance = _getTotalDistance();
    final totalFuel = _getTotalFuel();

    return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(widget.title),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                // Stats Card
                if (_seznam.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Statistika',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Počet záznamů'),
                                  Text(
                                    '${_seznam.length}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Celk. vzdálenost'),
                                  Text(
                                    '${totalDistance ?? 0} km',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Celk. palivo'),
                                  Text(
                                    '${totalFuel?.toStringAsFixed(2) ?? 0} l',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (avgConsumption != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text('Průměrná spotřeba'),
                                  Text(
                                    '${avgConsumption.toStringAsFixed(2)} l/100km',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Input Fields
                TextField(
                  controller: _mnozstviPalivaController,
                  decoration: const InputDecoration(
                    labelText: 'Množství paliva (l)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _stavTachometruController,
                  decoration: const InputDecoration(
                    labelText: 'Stav tachometru (km)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _pridejZaznam,
                  icon: const Icon(Icons.add),
                  label: const Text('Přidej záznam'),
                ),
                const SizedBox(height: 16),
                // Records List
                const Text(
                  'Záznamy o tankování:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _seznam.isEmpty
                      ? Center(
                          child: Text(
                            'Zatím žádné záznamy',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _seznam.length,
                          itemBuilder: (context, index) {
                            final record = _seznam[index];
                            final consumption = index > 0
                                ? _calculateConsumption(index - 1, index)
                                : null;

                            return Card(
                              child: ListTile(
                                title: Text('${record.mnozstviPaliva} l'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tachometr: ${record.stavTachometru} km'),
                                    if (consumption != null)
                                      Text(
                                        'Spotřeba: ${consumption.toStringAsFixed(2)} l/100km',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteZaznam(index),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
  }

  @override
  void dispose() {
    _mnozstviPalivaController.dispose();
    _stavTachometruController.dispose();
    super.dispose();
  }
}
