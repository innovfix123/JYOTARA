import 'dart:math' as math;
import 'package:flutter/material.dart';

class GoldenSunriseMark extends StatelessWidget {
  const GoldenSunriseMark({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: MediaQuery.sizeOf(context).width * .9,
    child: Stack(alignment: Alignment.center, children: [
      Image.asset('assets/images/jyotara_rasi_logo.png', width: MediaQuery.sizeOf(context).width * .85, height: MediaQuery.sizeOf(context).width * .85, filterQuality: FilterQuality.high),
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Sunrise(progress)))),
    ]),
  );
}
class _Sunrise extends CustomPainter {
  _Sunrise(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final pulse = math.sin(progress * math.pi);
    final radius = size.width * .32;
    canvas.drawCircle(center, radius, Paint()..shader = RadialGradient(colors: [Color.fromRGBO(255, 209, 113, .22 * pulse), const Color(0x00FFD171)]).createShader(Rect.fromCircle(center: center, radius: radius)));
    for (var i=0;i<12;i++) {
      final angle=-math.pi/2+i*math.pi/6;
      final light=(1-(progress*14-i).abs()).clamp(0.0,1.0);
      final point=center+Offset(math.cos(angle),math.sin(angle))*size.width*.29;
      canvas.drawCircle(point, 23, Paint()..shader=RadialGradient(colors:[Color.fromRGBO(255,215,140,light*.28),const Color(0x00FFD78C)]).createShader(Rect.fromCircle(center:point,radius:23)));
    }
  }
  @override bool shouldRepaint(_Sunrise old)=>old.progress!=progress;
}
class TempleLoginArtwork extends StatelessWidget {
  const TempleLoginArtwork({super.key});
  @override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[
    Image.asset('assets/images/temple_entrance_background.png',fit:BoxFit.cover,alignment:Alignment.topCenter,filterQuality:FilterQuality.high),
    const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0x181C1512),Color(0x281C1512),Color(0xDD1C1512),Color(0xF51C1512)],stops:[0,.35,.65,1]))),
  ]);
}
