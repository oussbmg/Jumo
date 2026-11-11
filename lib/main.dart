
import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() => runApp(const MarkerCreatorApp());

class MarkerCreatorApp extends StatelessWidget {
  const MarkerCreatorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Marker Creator',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
    home: const HomePage(),
  );
}

class Piece {
  final String name;
  final double width, height, quantity;
  Piece(this.name, this.width, this.height, this.quantity);
  double get area => width * height;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final pieces = <Piece>[];
  double fabricWidth = 150, markerLength = 300, fabricPrice = 0;

  Future<void> addPiece() async {
    final name = TextEditingController(text: 'Piece ${pieces.length + 1}');
    final w = TextEditingController();
    final h = TextEditingController();
    final q = TextEditingController(text: '1');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Add piece'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: w, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width (cm)')),
        TextField(controller: h, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (cm)')),
        TextField(controller: q, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
      ],
    ));
    if (ok == true) {
      final ww=double.tryParse(w.text) ?? 0, hh=double.tryParse(h.text) ?? 0, qq=double.tryParse(q.text) ?? 1;
      if (ww>0 && hh>0 && qq>0) setState(() => pieces.add(Piece(name.text.trim().isEmpty ? 'Piece' : name.text.trim(), ww, hh, qq)));
    }
  }

  @override Widget build(BuildContext context) {
    final markerArea=fabricWidth*markerLength;
    final used=pieces.fold<double>(0,(s,p)=>s+p.area*p.quantity);
    final eff=markerArea>0 ? used/markerArea*100 : 0;
    final cost=fabricPrice>0 ? markerArea/10000*fabricPrice : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Marker Creator V4')),
      floatingActionButton: FloatingActionButton.extended(onPressed: addPiece, icon: const Icon(Icons.add), label: const Text('Add piece')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          TextField(decoration: const InputDecoration(labelText:'Fabric width (cm)'), keyboardType:TextInputType.number, controller: TextEditingController(text:fabricWidth.toString()), onSubmitted:(v)=>setState(()=>fabricWidth=double.tryParse(v)??fabricWidth)),
          TextField(decoration: const InputDecoration(labelText:'Marker length (cm)'), keyboardType:TextInputType.number, controller: TextEditingController(text:markerLength.toString()), onSubmitted:(v)=>setState(()=>markerLength=double.tryParse(v)??markerLength)),
          TextField(decoration: const InputDecoration(labelText:'Fabric price / m²'), keyboardType:TextInputType.number, controller: TextEditingController(text:fabricPrice.toString()), onSubmitted:(v)=>setState(()=>fabricPrice=double.tryParse(v)??fabricPrice)),
        ]))),
        Card(child: SizedBox(height:260, child: CustomPaint(painter: MarkerPainter(fabricWidth, markerLength, pieces)))),
        const SizedBox(height:12),
        Text('Marker area: ${markerArea.toStringAsFixed(0)} cm²'),
        Text('Used piece area: ${used.toStringAsFixed(0)} cm²'),
        Text('Efficiency: ${eff.toStringAsFixed(1)}%'),
        Text('Waste: ${(100-eff).clamp(0,100).toStringAsFixed(1)}%'),
        Text('Marker fabric cost: ${cost.toStringAsFixed(2)}'),
        const SizedBox(height:12),
        ...pieces.asMap().entries.map((e)=>ListTile(
          title: Text('${e.value.name} — ${e.value.width} × ${e.value.height} cm'),
          subtitle: Text('Qty: ${e.value.quantity} • Area: ${e.value.area.toStringAsFixed(0)} cm²'),
          trailing: IconButton(icon:const Icon(Icons.delete), onPressed:()=>setState(()=>pieces.removeAt(e.key))),
        )),
      ]),
    );
  }
}

class MarkerPainter extends CustomPainter {
  final double width,length; final List<Piece> pieces;
  MarkerPainter(this.width,this.length,this.pieces);
  @override void paint(Canvas c, Size s) {
    final p=Paint()..style=PaintingStyle.fill..color=Colors.green.shade50;
    c.drawRect(Offset.zero & s,p);
    final border=Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=Colors.green.shade700;
    c.drawRect(Offset(4,4)&Size(s.width-8,s.height-8),border);
    final scale=math.min((s.width-16)/width,(s.height-16)/length);
    double x=8,y=8,rowH=0;
    for(final piece in pieces){
      final w=piece.width*scale, h=piece.height*scale;
      if(x+w>s.width-8){x=8;y+=rowH+6;rowH=0;}
      if(y+h>s.height-8) break;
      c.drawRect(Rect.fromLTWH(x,y,w,h), Paint()..color=Colors.white);
      c.drawRect(Rect.fromLTWH(x,y,w,h), border);
      final tp=TextPainter(text:TextSpan(text:piece.name,style:const TextStyle(fontSize:10,color:Colors.black)),textDirection:TextDirection.ltr)..layout(maxWidth:w);
      tp.paint(c,Offset(x+3,y+3));
      x+=w+6; rowH=math.max(rowH,h);
    }
  }
  @override bool shouldRepaint(covariant MarkerPainter old)=>true;
}
