import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../domain/entities/register_entity.dart';

/// Rompecabezas del registro: la imagen viene partida y barajada; se tocan dos
/// piezas para intercambiarlas hasta dejarla en orden. [onChanged] recibe la
/// pieza que hay en cada hueco (lo que el servidor espera en `orden`).
class CaptchaPuzzle extends StatefulWidget {
  final CaptchaChallenge challenge;
  final ValueChanged<List<int>> onChanged;

  /// Solo para pruebas; por defecto se descarga la imagen del desafío.
  final ImageProvider? image;

  const CaptchaPuzzle({
    super.key,
    required this.challenge,
    required this.onChanged,
    this.image,
  });

  @override
  State<CaptchaPuzzle> createState() => _CaptchaPuzzleState();
}

class _CaptchaPuzzleState extends State<CaptchaPuzzle> {
  late List<int> _order = List.of(widget.challenge.order);
  int? _selected;

  ui.Image? _image;
  ImageStream? _stream;
  late final ImageStreamListener _listener =
      ImageStreamListener(_onImage, onError: (_, _) {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(CaptchaPuzzle old) {
    super.didUpdateWidget(old);
    if (old.challenge.token != widget.challenge.token) {
      _order = List.of(widget.challenge.order);
      _selected = null;
      _image = null;
      _resolve();
    }
  }

  void _resolve() {
    final provider = widget.image ??
        NetworkImage('${ApiConstants.baseDomain}/${widget.challenge.imagePath}');
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    if (mounted) setState(() => _image = info.image);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  void _tap(int slot) {
    setState(() {
      final first = _selected;
      if (first == null) {
        _selected = slot;
      } else if (first == slot) {
        _selected = null;
      } else {
        final tmp = _order[first];
        _order[first] = _order[slot];
        _order[slot] = tmp;
        _selected = null;
        widget.onChanged(List.unmodifiable(_order));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final image = _image;
    final aspect = image == null ? 16 / 9 : image.width / image.height;
    final primary = Theme.of(context).colorScheme.primary;

    return AspectRatio(
      aspectRatio: aspect,
      child: Column(
        children: [
          for (var row = 0; row < c.rows; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < c.columns; col++)
                    Expanded(
                      child: _Tile(
                        key: Key('captcha-slot-${row * c.columns + col}'),
                        piece: _order[row * c.columns + col],
                        columns: c.columns,
                        rows: c.rows,
                        image: image,
                        selected: _selected == row * c.columns + col,
                        color: primary,
                        onTap: () => _tap(row * c.columns + col),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final int piece;
  final int columns;
  final int rows;
  final ui.Image? image;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Tile({
    super.key,
    required this.piece,
    required this.columns,
    required this.rows,
    required this.image,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : Colors.white,
            width: selected ? 3 : 1,
          ),
        ),
        child: image == null
            ? ColoredBox(
                color: Colors.black12,
                child: Center(child: Text('${piece + 1}')),
              )
            : CustomPaint(
                painter: _PiecePainter(image!, piece, columns, rows),
                size: Size.infinite,
              ),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  final ui.Image image;
  final int piece;
  final int columns;
  final int rows;

  _PiecePainter(this.image, this.piece, this.columns, this.rows);

  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width / columns;
    final h = image.height / rows;
    final src = Rect.fromLTWH((piece % columns) * w, (piece ~/ columns) * h, w, h);
    canvas.drawImageRect(
      image,
      src,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.image != image || old.piece != piece;
}
