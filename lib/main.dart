import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotřeba Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SpotrebaHomePage(title: 'Spotřeba App'),
    );
  }
}

class SpotrebaHomePage extends StatefulWidget {
  const SpotrebaHomePage({super.key, required this.title});

  final String title;

  @override
  State<SpotrebaHomePage> createState() => _SpotrebaHomePageState();
}

class ZaznamOTankovani {
  final double _mnozstviPaliva;
  final int _stavTachometru;

  ZaznamOTankovani(this._mnozstviPaliva, this._stavTachometru);
}

class _SpotrebaHomePageState extends State<SpotrebaHomePage> {
  List<ZaznamOTankovani> _seznam = [];

  final TextEditingController _mnozstviPalivaController = new TextEditingController();
  final TextEditingController _stavTachometruController = new TextEditingController();

  void _pridejZaznam() {
    setState(() {
      double mnozstviPaliva = double.parse(_mnozstviPalivaController.text.trim());
      int stavTachometru = int.parse(_stavTachometruController.text.trim());
      _seznam.add(ZaznamOTankovani(mnozstviPaliva, stavTachometru));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _mnozstviPalivaController,
              decoration: const InputDecoration(
                labelText: 'Množství paliva (l)',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _stavTachometruController,
              decoration: const InputDecoration(
                labelText: 'Stav tachometru (km)',
              ),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: _pridejZaznam,
              child: const Text('Přidej záznam'),
            ),
            const Text(
              'Záznamy o tankování:',
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _seznam.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('${_seznam[index]._mnozstviPaliva} l'),
                    subtitle: Text('${_seznam[index]._stavTachometru} km'),
                  );
                },
              ),
            ),          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pridejZaznam,
        tooltip: 'Přidej záznam',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
