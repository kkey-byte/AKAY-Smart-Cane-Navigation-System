import 'package:flutter/material.dart';



import '../../theme/gabay_theme.dart';



class FloatingRouteButton extends StatefulWidget {

  final VoidCallback onPressed;



  const FloatingRouteButton({super.key, required this.onPressed});



  @override

  State<FloatingRouteButton> createState() => _FloatingRouteButtonState();

}



class _FloatingRouteButtonState extends State<FloatingRouteButton>

    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  late Animation<double> _scaleAnimation;



  @override

  void initState() {

    super.initState();

    _controller = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 120),

      lowerBound: 0.92,

      upperBound: 1.0,

    )..value = 1.0;

    _scaleAnimation = CurvedAnimation(

      parent: _controller,

      curve: Curves.easeOutCubic,

    );

  }



  @override

  void dispose() {

    _controller.dispose();

    super.dispose();

  }



  Future<void> _handleTap() async {

    await _controller.reverse();

    await _controller.forward();

    widget.onPressed();

  }



  @override

  Widget build(BuildContext context) {

    final g = context.gabay;



    return ScaleTransition(

      scale: _scaleAnimation,

      child: Material(

        color: g.accent,

        borderRadius: BorderRadius.circular(18),

        elevation: 8,

        shadowColor: g.accent.withValues(alpha: 0.4),

        child: InkWell(

          borderRadius: BorderRadius.circular(18),

          onTap: _handleTap,

          child: const SizedBox(

            width: 58,

            height: 58,

            child: Icon(

              Icons.route_rounded,

              color: Colors.white,

              size: 28,

            ),

          ),

        ),

      ),

    );

  }

}

