import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/task.dart';
import '../../theme/task_colors.dart';

class SketchPage extends StatefulWidget {
  const SketchPage({super.key});
  @override
  State<SketchPage> createState() => _SketchPageState();
}

class _Stroke {
  final Color color;
  final List<Offset> points;
  _Stroke(this.color, this.points);
}

class _SketchPageState extends State<SketchPage> {
  final _canvas = GlobalKey();
  final List<_Stroke> _strokes = [];
  Color _color = TaskColor.indigo.value;
  bool _saving = false;
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final boundary =
          _canvas.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (mounted) {
        Navigator.pop<Uint8List>(context, data!.buffer.asUint8List());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le croquis n’a pas pu être enregistré. Réessayez.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mon croquis'),
      actions: [
        IconButton(
          tooltip: 'Annuler le dernier trait',
          onPressed: _strokes.isEmpty || _saving
              ? null
              : () => setState(_strokes.removeLast),
          icon: const Icon(Icons.undo),
        ),
        TextButton(
          onPressed: _strokes.isEmpty || _saving ? null : _save,
          child: Text(_saving ? 'Enregistrement…' : 'Joindre'),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              for (final tone in TaskColor.values.where(
                (c) => c != TaskColor.automatic,
              ))
                IconButton(
                  tooltip: tone.label,
                  onPressed: () => setState(() => _color = tone.value),
                  icon: Icon(
                    _color == tone.value ? Icons.check_circle : Icons.circle,
                    color: tone.value,
                  ),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Dessinez au doigt, au stylet ou à la souris.'),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RepaintBoundary(
                key: _canvas,
                child: ColoredBox(
                  color: Colors.white,
                  child: GestureDetector(
                    onPanStart: _saving
                        ? null
                        : (d) => setState(
                            () => _strokes.add(
                              _Stroke(_color, [d.localPosition]),
                            ),
                          ),
                    onPanUpdate: _saving
                        ? null
                        : (d) => setState(
                            () => _strokes.last.points.add(d.localPosition),
                          ),
                    child: CustomPaint(
                      painter: _SketchPainter(_strokes),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SketchPainter extends CustomPainter {
  final List<_Stroke> strokes;
  _SketchPainter(this.strokes);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, 1.5, paint);
      }
      for (var i = 1; i < stroke.points.length; i++) {
        canvas.drawLine(stroke.points[i - 1], stroke.points[i], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
