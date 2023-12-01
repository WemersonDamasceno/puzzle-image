import 'dart:developer';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: PuzzleGameScreen(),
    );
  }
}

class PuzzleGameScreen extends StatelessWidget {
  const PuzzleGameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quebra-Cabeça'),
      ),
      body: const Center(
        child: PuzzleWidget(
          imageAssetPath:
              'assets/images/image.jpg', // Substitua pelo caminho da sua imagem.
        ),
      ),
    );
  }
}

class PuzzleWidget extends StatelessWidget {
  final String imageAssetPath;

  const PuzzleWidget({Key? key, required this.imageAssetPath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _loadImage(imageAssetPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          ui.Image image = snapshot.data!;
          List<Piece?> pieces = _splitImage(image, 3, 3);
          return PuzzleGrid(pieces: pieces, image: image);
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    ByteData data = await rootBundle.load(assetPath);
    List<int> bytes = data.buffer.asUint8List();
    return decodeImageFromList(Uint8List.fromList(bytes));
  }

  List<Piece?> _splitImage(ui.Image image, int rows, int cols) {
    List<Piece?> pieces = [];
    int pieceWidth = image.width ~/ cols;
    int pieceHeight = image.height ~/ rows;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        int x = col * pieceWidth;
        int y = row * pieceHeight;

        if (row == rows - 1 && col == cols - 1) {
          pieces.add(null);
        } else {
          Rect pieceRect = Rect.fromPoints(
            Offset(x.toDouble(), y.toDouble()),
            Offset((col + 1) * pieceWidth.toDouble(),
                (row + 1) * pieceHeight.toDouble()),
          );

          PictureRecorder recorder = PictureRecorder();
          Canvas canvas = Canvas(recorder);
          canvas.drawImageRect(
              image,
              pieceRect,
              Rect.fromPoints(const Offset(0, 0),
                  Offset(pieceWidth.toDouble(), pieceHeight.toDouble())),
              Paint());

          pieces.add(Piece(pieceRect, recorder.endRecording(), row, col));
        }
      }
    }

    return pieces;
  }
}

class PuzzleGrid extends StatefulWidget {
  final List<Piece?> pieces;
  final ui.Image image;

  const PuzzleGrid({Key? key, required this.pieces, required this.image})
      : super(key: key);

  @override
  State<PuzzleGrid> createState() => _PuzzleGridState();
}

class _PuzzleGridState extends State<PuzzleGrid> {
  late List<Piece?> pieces;
  late List<bool> pieceCorrect;
  late int emptyIndex;

  @override
  void initState() {
    super.initState();
    pieces = List.from(widget.pieces);
    pieceCorrect = List.generate(pieces.length, (index) => false);
    pieces.shuffle();
    emptyIndex = pieces.indexWhere((piece) => piece == null);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemCount: pieces.length,
      itemBuilder: (context, index) {
        return Draggable(
          data: index,
          feedback: pieces[index] != null
              ? CustomPaint(
                  painter: PuzzlePiecePainter(pieces[index]!),
                )
              : Container(),
          child: DragTarget<int>(
            builder: (context, candidateData, rejectedData) {
              return GestureDetector(
                onTap: () => _playSoundIfCorrect(index),
                child: pieces[index] != null
                    ? Draggable(
                        // Make the image draggable
                        data: index,
                        feedback: SizedBox(
                          width: 10,
                          height: 10,
                          child: CustomPaint(
                            painter: PuzzlePiecePainter(pieces[index]!),
                          ),
                        ),
                        child: CustomPaint(
                          painter: PuzzlePiecePainter(pieces[index]!),
                        ),
                      )
                    : Container(
                        height: 10,
                        width: 10,
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                      ),
              );
            },
            onWillAccept: (data) {
              // Allow the piece to be accepted
              return true;
            },
            onAccept: (data) {
              // Handle piece movement
              _handlePieceMovement(data, index);
            },
          ),
        );
      },
    );
  }

  void _playSoundIfCorrect(int index) {
    if (pieceCorrect[index]) {
      log('Parabéns! Peça na posição correta!');
    }
  }

  void _checkIfPuzzleIsComplete() {
    bool allCorrect = true;
    for (int i = 0; i < pieces.length; i++) {
      if (pieces[i] != null) {
        int row = i ~/ 3;
        int col = i % 3;
        if (pieces[i]!.row != row || pieces[i]!.col != col) {
          allCorrect = false;
          break;
        }
      }
    }

    if (allCorrect) {
      setState(() {
        for (int i = 0; i < pieces.length; i++) {
          pieceCorrect[i] = true;
        }
      });
    }
  }

  void _handlePieceMovement(int fromIndex, int toIndex) {
    setState(() {
      // Swap the pieces in the list
      Piece? temp = pieces[fromIndex];
      pieces[fromIndex] = pieces[toIndex];
      pieces[toIndex] = temp;

      // Update the empty index
      emptyIndex = fromIndex;

      // Check if the puzzle is complete
      _checkIfPuzzleIsComplete();
    });
  }
}

class Piece {
  final Rect rect;
  final Picture picture;
  final int row;
  final int col;

  Piece(this.rect, this.picture, this.row, this.col);
}

class PuzzlePiecePainter extends CustomPainter {
  final Piece piece;

  PuzzlePiecePainter(this.piece);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(piece.picture);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
