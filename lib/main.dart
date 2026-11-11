
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MarkerCreatorApp());

class MarkerCreatorApp extends StatelessWidget {
  const MarkerCreatorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Marker Creator',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: const Color(0xfff5f7f5),
      ),
      home: const MarkerPage(),
    );
  }
}

class Piece {
  String name;
  int quantity;
  List<Offset> points; // normalized 0..1
  Offset offset;
  double rotation;
  Piece({
    required this.name,
    required this.quantity,
    required this.points,
    this.offset = Offset.zero,
    this.rotation = 0,
  });

  double areaNorm() {
    if (points.length < 3) return 0;
    double a = 0;
    for (int i = 0; i < points.length; i++) {
      final p = points[i], q = points[(i + 1) % points.length];
      a += p.dx * q.dy - q.dx * p.dy;
    }
    return a.abs() / 2;
  }

  Offset center() {
    if (points.isEmpty) return Offset.zero;
    var x = 0.0, y = 0.0;
    for (final p in points) { x += p.dx; y += p.dy; }
    return Offset(x / points.length, y / points.length) + offset;
  }

  Map<String, dynamic> toJson() => {
    'name': name, 'quantity': quantity,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'offset': [offset.dx, offset.dy], 'rotation': rotation,
  };

  factory Piece.fromJson(Map<String,dynamic> j) => Piece(
    name: j['name'] ?? 'Piece',
    quantity: (j['quantity'] ?? 1) as int,
    points: (j['points'] as List).map<Offset>((p) => Offset(
      (p[0] as num).toDouble(), (p[1] as num).toDouble())).toList(),
    offset: Offset(
      ((j['offset']?[0] ?? 0) as num).toDouble(),
      ((j['offset']?[1] ?? 0) as num).toDouble()),
    rotation: ((j['rotation'] ?? 0) as num).toDouble(),
  );
}

class MarkerPage extends StatefulWidget {
  const MarkerPage({super.key});
  @override State<MarkerPage> createState() => _MarkerPageState();
}

class _MarkerPageState extends State<MarkerPage> {
  final widthCtrl = TextEditingController(text: '160');
  final lengthCtrl = TextEditingController(text: '200');
  final priceCtrl = TextEditingController(text: '0');
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');

  Uint8List? markerImage;
  final pieces = <Piece>[];
  List<Offset> drawing = [];
  int? selected;
  bool drawingMode = false;
  Size canvasSize = Size.zero;

  double get fabricWidth => double.tryParse(widthCtrl.text.replaceAll(',', '.')) ?? 0;
  double get markerLength => double.tryParse(lengthCtrl.text.replaceAll(',', '.')) ?? 0;
  double get fabricPrice => double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double get markerAreaM2 => fabricWidth * markerLength / 10000;
  double get markerCost => markerAreaM2 * fabricPrice;

  double pieceAreaM2(Piece p) => p.areaNorm() * canvasSize.width * canvasSize.height / 10000;
  double pieceFabricCost(Piece p) {
    if (markerAreaM2 <= 0) return 0;
    return markerCost * (pieceAreaM2(p) * p.quantity) / markerAreaM2;
  }

  Future<void> importImage() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r?.files.single.bytes != null) setState(() => markerImage = r!.files.single.bytes);
  }

  void startPiece() {
    if (!drawingMode) {
      setState(() { drawingMode = true; drawing = []; selected = null; });
    } else if (drawing.length >= 3) {
      final name = nameCtrl.text.trim().isEmpty ? 'Piece ${pieces.length + 1}' : nameCtrl.text.trim();
      final qty = int.tryParse(qtyCtrl.text) ?? 1;
      setState(() {
        pieces.add(Piece(name: name, quantity: qty.clamp(1, 999), points: List.of(drawing)));
        drawing = [];
        drawingMode = false;
        selected = pieces.length - 1;
      });
    }
  }

  Offset normalizedFromCanvas(Offset p) => Offset(
    (p.dx / canvasSize.width).clamp(0.0, 1.0),
    (p.dy / canvasSize.height).clamp(0.0, 1.0),
  );

  Offset canvasFromNorm(Offset p) => Offset(p.dx * canvasSize.width, p.dy * canvasSize.height);

  List<Offset> transformed(Piece piece) {
    final c = piece.center();
    final center = canvasFromNorm(c);
    return piece.points.map((n) {
      final base = canvasFromNorm(n + piece.offset);
      final v = base - center;
      final cs = math.cos(piece.rotation), sn = math.sin(piece.rotation);
      return center + Offset(v.dx * cs - v.dy * sn, v.dx * sn + v.dy * cs);
    }).toList();
  }

  int hitPiece(Offset pos) {
    for (int i = pieces.length - 1; i >= 0; i--) {
      final pts = transformed(pieces[i]);
      if (_inside(pos, pts)) return i;
    }
    return -1;
  }

  bool _inside(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i=0,j=poly.length-1;i<poly.length;j=i++) {
      final xi=poly[i].dx, yi=poly[i].dy, xj=poly[j].dx, yj=poly[j].dy;
      final cross = ((yi>p.dy)!=(yj>p.dy)) &&
          (p.dx < (xj-xi)*(p.dy-yi)/(yj-yi+0.0000001)+xi);
      if (cross) inside=!inside;
    }
    return inside;
  }

  void onCanvasTap(Offset pos) {
    if (canvasSize == Size.zero) return;
    if (drawingMode) {
      setState(() => drawing.add(normalizedFromCanvas(pos)));
    } else {
      final hit = hitPiece(pos);
      setState(() => selected = hit >= 0 ? hit : null);
    }
  }

  void onPanUpdate(DragUpdateDetails d) {
    if (drawingMode || selected == null || canvasSize == Size.zero) return;
    final p = pieces[selected!];
    final delta = Offset(d.delta.dx / canvasSize.width, d.delta.dy / canvasSize.height);
    setState(() => p.offset += delta);
  }

  void onScaleUpdate(ScaleUpdateDetails d) {
    if (drawingMode || selected == null || canvasSize == Size.zero) return;
    if (d.rotation.abs() > 0.002) {
      setState(() => pieces[selected!].rotation += d.rotation);
    }
  }

  Future<void> saveProject() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'width': widthCtrl.text, 'length': lengthCtrl.text, 'price': priceCtrl.text,
      'pieces': pieces.map((p)=>p.toJson()).toList(),
    };
    await prefs.setString('marker_project', jsonEncode(data));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project saved')));
  }

  Future<void> loadProject() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('marker_project');
    if (raw == null) return;
    final j = jsonDecode(raw);
    setState(() {
      widthCtrl.text = j['width'] ?? '160';
      lengthCtrl.text = j['length'] ?? '200';
      priceCtrl.text = j['price'] ?? '0';
      pieces..clear()..addAll((j['pieces'] as List).map((x)=>Piece.fromJson(x)));
      selected = pieces.isEmpty ? null : 0;
    });
  }

  void clearAll() {
    setState(() { pieces.clear(); drawing.clear(); selected=null; drawingMode=false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marker Creator'),
        actions: [
          IconButton(onPressed: loadProject, icon: const Icon(Icons.folder_open), tooltip: 'Load'),
          IconButton(onPressed: saveProject, icon: const Icon(Icons.save), tooltip: 'Save'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _settingsCard(),
          const SizedBox(height: 10),
          _markerCard(),
          const SizedBox(height: 10),
          _piecesCard(),
          const SizedBox(height: 10),
          _summaryCard(),
        ],
      ),
    );
  }

  Widget _settingsCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('1. Marker settings', style: TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        const SizedBox(height:8),
        Row(children: [
          Expanded(child: _field(widthCtrl, 'Fabric width (cm)')),
          const SizedBox(width:8),
          Expanded(child: _field(lengthCtrl, 'Marker length (cm)')),
        ]),
        const SizedBox(height:8),
        Row(children: [
          Expanded(child: _field(priceCtrl, 'Fabric price / m²')),
          const SizedBox(width:8),
          ElevatedButton.icon(onPressed: importImage, icon: const Icon(Icons.image), label: const Text('Marker image')),
        ]),
        const SizedBox(height:6),
        Text('Marker area: ${markerAreaM2.toStringAsFixed(3)} m²   •   Fabric cost: ${markerCost.toStringAsFixed(2)}'),
      ]),
    ),
  );

  Widget _field(TextEditingController c, String label) => TextField(
    controller:c, keyboardType: const TextInputType.numberWithOptions(decimal:true),
    onChanged: (_) => setState((){}), decoration: InputDecoration(labelText:label,border:const OutlineInputBorder()),
  );

  Widget _markerCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('2. Marker canvas', style: TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        const SizedBox(height:6),
        Text(drawingMode
          ? 'DRAW MODE: tap points around the piece, then press Finish piece.'
          : 'Tap a piece to select it. Drag to move. Two-finger rotate.'),
        const SizedBox(height:8),
        LayoutBuilder(builder: (context, box) {
          final ratio = fabricWidth > 0 && markerLength > 0 ? fabricWidth / markerLength : 0.8;
          final h = math.min(560.0, math.max(280.0, box.maxWidth / (ratio <= 0 ? 0.8 : ratio)));
          return SizedBox(
            height:h,
            width:box.maxWidth,
            child: LayoutBuilder(builder:(context,b) {
              canvasSize = Size(b.maxWidth,b.maxHeight);
              return GestureDetector(
                onTapUp:(d)=>onCanvasTap(d.localPosition),
                onPanUpdate:onPanUpdate,
                onScaleUpdate:onScaleUpdate,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (markerImage != null)
                      Image.memory(
                        markerImage!,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      )
                    else
                      const ColoredBox(color: Colors.white),
                    CustomPaint(
                      painter: MarkerPainter(
                        pieces: pieces, drawing: drawing,
                        selected: selected, size: canvasSize,
                        transform: (p) => transformed(pieces[p]),
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        }),
        const SizedBox(height:8),
        Row(children: [
          Expanded(child: TextField(controller:nameCtrl, decoration:const InputDecoration(labelText:'Piece name',border:OutlineInputBorder()))),
          const SizedBox(width:8),
          SizedBox(width:90, child: TextField(controller:qtyCtrl, keyboardType:TextInputType.number, decoration:const InputDecoration(labelText:'Qty',border:OutlineInputBorder()))),
          const SizedBox(width:8),
          ElevatedButton(
            onPressed: startPiece,
            child: Text(drawingMode ? 'Finish' : 'Draw piece'),
          ),
        ]),
        if (selected != null && !drawingMode) ...[
          const SizedBox(height:6),
          Row(children:[
            Expanded(child: Text('Selected: ${pieces[selected!].name}')),
            IconButton(onPressed:()=>setState(()=>pieces.removeAt(selected!)), icon:const Icon(Icons.delete)),
          ])
        ],
      ]),
    ),
  );

  Widget _piecesCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        const Text('3. Pieces', style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        if (pieces.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('No pieces yet. Draw your first irregular piece.')),
        ...List.generate(pieces.length,(i){
          final p=pieces[i];
          final area=pieceAreaM2(p);
          return ListTile(
            selected:selected==i,
            onTap:()=>setState(()=>selected=i),
            title:Text('${p.name}  ×${p.quantity}'),
            subtitle:Text('Area: ${area.toStringAsFixed(4)} m²  •  Fabric: ${pieceFabricCost(p).toStringAsFixed(2)}'),
          );
        })
      ]),
    ),
  );

  Widget _summaryCard() {
    final used = pieces.fold<double>(0,(s,p)=>s+pieceAreaM2(p)*p.quantity);
    final eff = markerAreaM2>0 ? used/markerAreaM2*100 : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('4. Cost & efficiency',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
          Text('Total piece area: ${used.toStringAsFixed(4)} m²'),
          Text('Efficiency: ${eff.toStringAsFixed(1)}%'),
          Text('Waste: ${(100-eff).clamp(0,100).toStringAsFixed(1)}%'),
          Text('Marker fabric cost: ${markerCost.toStringAsFixed(2)}'),
          const SizedBox(height:8),
          OutlinedButton.icon(onPressed:clearAll,icon:const Icon(Icons.delete_sweep),label:const Text('Clear pieces')),
        ]),
      ),
    );
  }
}

class MarkerPainter extends CustomPainter {
  final List<Piece> pieces;
  final List<Offset> drawing;
  final int? selected;
  final Size size;
  final List<Offset> Function(int) transform;
  MarkerPainter({required this.pieces,required this.drawing,required this.selected,required this.size,required this.transform});

  @override
  void paint(Canvas c, Size s) {
    final border=Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=Colors.grey;
    c.drawRect(Offset.zero&s,border);

    for(int i=0;i<pieces.length;i++){
      final pts=transform(i);
      if(pts.length<3) continue;
      final path=Path()..moveTo(pts[0].dx,pts[0].dy);
      for(final p in pts.skip(1)) path.lineTo(p.dx,p.dy);
      path.close();
      final fill=Paint()..color= i==selected ? Colors.green.withOpacity(.28) : Colors.blue.withOpacity(.18);
      c.drawPath(path,fill);
      final line=Paint()..style=PaintingStyle.stroke..strokeWidth=i==selected?3:1.5..color=i==selected?Colors.green:Colors.blue;
      c.drawPath(path,line);
      final center=pts.reduce((a,b)=>a+b)/pts.length.toDouble();
      final tp=TextPainter(text:TextSpan(text:pieces[i].name,style:const TextStyle(color:Colors.black,fontWeight:FontWeight.bold)),textDirection:TextDirection.ltr)..layout();
      tp.paint(c,center-Offset(tp.width/2,tp.height/2));
    }

    if(drawing.isNotEmpty){
      final pts=drawing.map((p)=>Offset(p.dx*s.width,p.dy*s.height)).toList();
      final line=Paint()..style=PaintingStyle.stroke..strokeWidth=3..color=Colors.orange;
      for(int i=0;i<pts.length-1;i++) c.drawLine(pts[i],pts[i+1],line);
      final dot=Paint()..color=Colors.orange;
      for(final p in pts) c.drawCircle(p,5,dot);
    }
  }
  @override bool shouldRepaint(covariant MarkerPainter old)=>true;
}
