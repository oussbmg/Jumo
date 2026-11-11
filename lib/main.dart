
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MarkerCreatorApp());

class MarkerCreatorApp extends StatelessWidget {
  const MarkerCreatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Marker Creator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MarkerCreatorPage(),
    );
  }
}

class Piece {
  String name;
  double widthCm;
  double heightCm;
  double xCm;
  double yCm;
  double rotation;

  Piece({
    required this.name,
    required this.widthCm,
    required this.heightCm,
    this.xCm = 0,
    this.yCm = 0,
    this.rotation = 0,
  });

  double get areaM2 => (widthCm * heightCm) / 10000;
}

class MarkerCreatorPage extends StatefulWidget {
  const MarkerCreatorPage({super.key});

  @override
  State<MarkerCreatorPage> createState() => _MarkerCreatorPageState();
}

class _MarkerCreatorPageState extends State<MarkerCreatorPage> {
  final pieces = <Piece>[];
  double fabricWidth = 160;
  double markerLength = 250;
  double fabricPrice = 800;
  String? imageName;

  double get markerArea => fabricWidth * markerLength / 10000;
  double get piecesArea => pieces.fold(0, (s, p) => s + p.areaM2);
  double get efficiency =>
      markerArea == 0 ? 0 : (piecesArea / markerArea) * 100;
  double get waste => math.max(0, 100 - efficiency);
  double get markerFabricCost => markerLength / 100 * fabricPrice;

  Future<void> addPiece() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PieceDialog(),
    );
    if (result == null) return;
    setState(() {
      pieces.add(Piece(
        name: result['name'],
        widthCm: result['width'],
        heightCm: result['height'],
        xCm: 5,
        yCm: 5,
      ));
    });
  }

  Future<void> editPiece(int index) async {
    final p = pieces[index];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PieceDialog(
        initialName: p.name,
        initialWidth: p.widthCm,
        initialHeight: p.heightCm,
      ),
    );
    if (result == null) return;
    setState(() {
      p.name = result['name'];
      p.widthCm = result['width'];
      p.heightCm = result['height'];
    });
  }

  Future<void> importMarkerImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (result != null) {
      setState(() => imageName = result.files.single.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marker Creator'),
        actions: [
          IconButton(
            tooltip: 'Importer une image du marker',
            onPressed: importMarkerImage,
            icon: const Icon(Icons.image_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _topForm(),
          Expanded(child: _markerEditor()),
          _bottomStats(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addPiece,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter pièce'),
      ),
    );
  }

  Widget _topForm() => Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _numberField('Largeur tissu (cm)', fabricWidth,
                (v) => setState(() => fabricWidth = v)),
            _numberField('Longueur marker (cm)', markerLength,
                (v) => setState(() => markerLength = v)),
            _numberField('Prix tissu (DA/m)', fabricPrice,
                (v) => setState(() => fabricPrice = v)),
            if (imageName != null)
              Chip(
                avatar: const Icon(Icons.image),
                label: Text(imageName!),
                onDeleted: () => setState(() => imageName = null),
              ),
          ],
        ),
      );

  Widget _numberField(String label, double value, ValueChanged<double> onChanged) {
    final controller = TextEditingController(text: value.toStringAsFixed(0));
    return SizedBox(
      width: 190,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (s) => onChanged(double.tryParse(s) ?? value),
      ),
    );
  }

  Widget _markerEditor() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          (constraints.maxWidth - 40) / math.max(fabricWidth, 1),
          (constraints.maxHeight - 40) / math.max(markerLength, 1),
        ).clamp(0.5, 3.0);

        return Center(
          child: Container(
            width: fabricWidth * scale,
            height: markerLength * scale,
            decoration: BoxDecoration(
              border: Border.all(width: 2),
              color: Colors.grey.shade100,
            ),
            child: Stack(
              children: [
                for (int i = 0; i < pieces.length; i++)
                  _pieceWidget(i, scale),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pieceWidget(int index, double scale) {
    final p = pieces[index];
    return Positioned(
      left: p.xCm * scale,
      top: p.yCm * scale,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            p.xCm = (p.xCm + d.delta.dx / scale)
                .clamp(0, math.max(0, fabricWidth - p.widthCm));
            p.yCm = (p.yCm + d.delta.dy / scale)
                .clamp(0, math.max(0, markerLength - p.heightCm));
          });
        },
        onDoubleTap: () => editPiece(index),
        child: Transform.rotate(
          angle: p.rotation * math.pi / 180,
          child: Container(
            width: p.widthCm * scale,
            height: p.heightCm * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(width: 1.5),
              color: Colors.green.withOpacity(.18),
            ),
            child: Text(
              p.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomStats() {
    return Material(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 22,
          runSpacing: 8,
          children: [
            Text('Marker: ${markerArea.toStringAsFixed(3)} m²'),
            Text('Pièces: ${piecesArea.toStringAsFixed(3)} m²'),
            Text('Rendement: ${efficiency.toStringAsFixed(1)}%'),
            Text('Déchets: ${waste.toStringAsFixed(1)}%'),
            Text('Tissu Marker: ${markerFabricCost.toStringAsFixed(2)} DA'),
          ],
        ),
      ),
    );
  }
}

class _PieceDialog extends StatefulWidget {
  final String initialName;
  final double initialWidth;
  final double initialHeight;

  const _PieceDialog({
    this.initialName = 'Pièce',
    this.initialWidth = 50,
    this.initialHeight = 50,
  });

  @override
  State<_PieceDialog> createState() => _PieceDialogState();
}

class _PieceDialogState extends State<_PieceDialog> {
  late final name = TextEditingController(text: widget.initialName);
  late final width = TextEditingController(text: widget.initialWidth.toString());
  late final height = TextEditingController(text: widget.initialHeight.toString());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une pièce'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
          TextField(controller: width, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Largeur (cm)')),
          TextField(controller: height, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hauteur (cm)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'name': name.text.trim().isEmpty ? 'Pièce' : name.text.trim(),
            'width': double.tryParse(width.text) ?? 0,
            'height': double.tryParse(height.text) ?? 0,
          }),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
