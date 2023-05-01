import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

typedef SlidingPanelBuilder = Widget Function(ScrollController sc);

class SlidingCard extends StatefulWidget {
  const SlidingCard({Key? key, this.panelBuilder, this.body, this.panel})
      : super(key: key);

  final SlidingPanelBuilder? panelBuilder;
  final Widget? body;
  final Widget? panel;
  @override
  State<SlidingCard> createState() => _SlidingCardState();
}

class _SlidingCardState extends State<SlidingCard> {
  double _panelHeightOpen = 0;
  double _panelHeightClosed = 95.0;

  @override
  Widget build(BuildContext context) {
    _panelHeightOpen = MediaQuery.of(context).size.height * .80;
    return SlidingUpPanel(
      maxHeight: _panelHeightOpen,
      minHeight: _panelHeightClosed,
      parallaxEnabled: true,
      parallaxOffset: .5,
      body: widget.body,
      panelBuilder: widget.panelBuilder,
      panel: widget.panel,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(18.0),
        topRight: Radius.circular(18.0),
      ),
    );
  }
}
