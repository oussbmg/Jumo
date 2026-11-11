
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MarkerCreatorApp());

class MarkerCreatorApp extends StatelessWidget {
  const MarkerCreatorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Marker Creator',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green), useMaterial3: true),
    home: const MarkerCreatorPage(),
  );
}

class Piece {
  Piece({required this.name, required this.points, this.quantity=1});
  String name; List<Offset> points; int quantity;
  double get areaCm2 {
    if (points.length < 3) return 0;
    double s=0;
    for (int i=0;i<points.length;i++) {
      final a=points[i], b=points[(i+1)%points.length];
      s += a.dx*b.dy-b.dx*a.dy;
    }
    return s.abs()/2;
  }
  double get areaM2 => areaCm2/10000;
}

class MarkerCreatorPage extends StatefulWidget {
  const MarkerCreatorPage({super.key});
  @override State<MarkerCreatorPage> createState()=>_MarkerCreatorPageState();
}

class _MarkerCreatorPageState extends State<MarkerCreatorPage> {
  double fabricWidth=160, markerLength=250, fabricPrice=800;
  Uint8List? image;
  final pieces=<Piece>[];
  final drawing=<Offset>[];
  bool isDrawing=false;

  double get markerArea=>fabricWidth*markerLength/10000;
  double get piecesArea=>pieces.fold(0,(s,p)=>s+p.areaM2*p.quantity);
  double get efficiency=>markerArea==0?0:(piecesArea/markerArea)*100;
  double get waste=>math.max(0,100-efficiency);
  double get fabricCost=>markerLength/100*fabricPrice;

  Future<void> pickImage() async {
    final r=await FilePicker.platform.pickFiles(type:FileType.image,withData:true);
    if(r?.files.single.bytes!=null) setState(()=>image=r!.files.single.bytes);
  }

  void startDraw()=>setState(()=>{isDrawing=true,drawing.clear()});
  void cancelDraw()=>setState(()=>{isDrawing=false,drawing.clear()});

  void addPoint(Offset px,double scale) {
    if(!isDrawing)return;
    setState(()=>drawing.add(Offset(
      (px.dx/scale).clamp(0,fabricWidth),
      (px.dy/scale).clamp(0,markerLength),
    )));
  }

  Future<void> finishDraw() async {
    if(drawing.length<3){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('حدد 3 نقاط على الأقل')));return;}
    final r=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>const PieceDialog());
    if(r==null)return;
    setState(() {
      pieces.add(Piece(name:r['name'],points:List.of(drawing),quantity:r['quantity']));
      drawing.clear(); isDrawing=false;
    });
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Marker Creator'),actions:[IconButton(onPressed:pickImage,icon:const Icon(Icons.image))]),
    body:Column(children:[settings(),Expanded(child:editor()),pieceList(),stats()]),
  );

  Widget field(String label,double v,ValueChanged<double> onChanged)=>SizedBox(
    width:145,child:TextField(
      controller:TextEditingController(text:v.toStringAsFixed(1)),
      keyboardType:const TextInputType.numberWithOptions(decimal:true),
      decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true),
      onSubmitted:(s)=>onChanged(double.tryParse(s)??v),
    ));

  Widget settings()=>Padding(
    padding:const EdgeInsets.all(8),child:Wrap(spacing:8,runSpacing:8,children:[
      field('عرض القماش cm',fabricWidth,(v)=>setState(()=>fabricWidth=v)),
      field('طول Marker cm',markerLength,(v)=>setState(()=>markerLength=v)),
      field('السعر DA/m',fabricPrice,(v)=>setState(()=>fabricPrice=v)),
      FilledButton.icon(onPressed:isDrawing?finishDraw:startDraw,icon:Icon(isDrawing?Icons.check:Icons.edit),label:Text(isDrawing?'Terminer':'Dessiner pièce')),
      if(isDrawing) OutlinedButton(onPressed:cancelDraw,child:const Text('Annuler')),
    ]));

  Widget editor()=>LayoutBuilder(builder:(c,cs){
    final scale=math.min((cs.maxWidth-20)/fabricWidth,(cs.maxHeight-20)/markerLength);
    final w=fabricWidth*scale,h=markerLength*scale;
    return Center(child:Container(width:w,height:h,clipBehavior:Clip.hardEdge,
      decoration:BoxDecoration(color:Colors.grey.shade100,border:Border.all(width:2)),
      child:Stack(children:[
        if(image!=null)Positioned.fill(child:Image.memory(image!,fit:BoxFit.fill)),
        Positioned.fill(child:GestureDetector(
          onTapUp:(d)=>addPoint(d.localPosition,scale),
          child:CustomPaint(painter:MarkerPainter(pieces,drawing,scale,isDrawing)),
        )),
      ])));
  });

  Widget pieceList()=>SizedBox(height:65,child:ListView(
    scrollDirection:Axis.horizontal,
    children:[for(int i=0;i<pieces.length;i++)Card(child:Row(children:[
      Padding(padding:const EdgeInsets.all(8),child:Text('${pieces[i].name} ×${pieces[i].quantity}  ${pieces[i].areaM2.toStringAsFixed(3)} m²')),
      IconButton(onPressed:()=>setState(()=>pieces.removeAt(i)),icon:const Icon(Icons.delete_outline))
    ]))]));

  Widget stats()=>Material(elevation:6,child:Padding(padding:const EdgeInsets.all(10),child:Wrap(spacing:16,children:[
    Text('Marker ${markerArea.toStringAsFixed(3)} m²'),
    Text('Pièces ${piecesArea.toStringAsFixed(3)} m²'),
    Text('Rendement ${efficiency.toStringAsFixed(1)}%'),
    Text('Déchets ${waste.toStringAsFixed(1)}%'),
    Text('Tissu ${fabricCost.toStringAsFixed(2)} DA'),
  ])));
}

class MarkerPainter extends CustomPainter {
  final List<Piece> pieces; final List<Offset> current; final double scale; final bool drawing;
  MarkerPainter(this.pieces,this.current,this.scale,this.drawing);
  @override void paint(Canvas c,Size s){
    final fill=Paint()..color=Colors.green.withOpacity(.18)..style=PaintingStyle.fill;
    final line=Paint()..color=Colors.green.shade800..style=PaintingStyle.stroke..strokeWidth=1.5;
    for(final p in pieces) drawPoly(c,p.points,fill,line);
    if(drawing && current.isNotEmpty){
      final orange=Paint()..color=Colors.orange..style=PaintingStyle.stroke..strokeWidth=2;
      drawPoly(c,current,Paint()..color=Colors.orange.withOpacity(.12)..style=PaintingStyle.fill,orange);
      for(final p in current)c.drawCircle(Offset(p.dx*scale,p.dy*scale),4,Paint()..color=Colors.orange);
    }
  }
  void drawPoly(Canvas c,List<Offset> pts,Paint fill,Paint line){
    if(pts.isEmpty)return;
    final path=Path()..moveTo(pts.first.dx*scale,pts.first.dy*scale);
    for(final p in pts.skip(1))path.lineTo(p.dx*scale,p.dy*scale);
    if(pts.length>=3)path.close();
    c.drawPath(path,fill);c.drawPath(path,line);
  }
  @override bool shouldRepaint(covariant MarkerPainter old)=>true;
}

class PieceDialog extends StatefulWidget {
  const PieceDialog({super.key});
  @override State<PieceDialog> createState()=>_PieceDialogState();
}
class _PieceDialogState extends State<PieceDialog>{
  final name=TextEditingController(text:'Pièce'), qty=TextEditingController(text:'1');
  @override Widget build(BuildContext c)=>AlertDialog(
    title:const Text('معلومات القطعة'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'اسم القطعة')),
      TextField(controller:qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الكمية')),
    ]),actions:[
      TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),
      FilledButton(onPressed:()=>Navigator.pop(c,{'name':name.text.trim().isEmpty?'Pièce':name.text.trim(),'quantity':int.tryParse(qty.text)??1}),child:const Text('حفظ'))
    ]);
}
