import 'package:flutter/material.dart';

class ScrollHideAppBarScaffold extends StatelessWidget {
  const ScrollHideAppBarScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.backgroundColor = const Color.fromRGBO(19, 67, 107, 1),
    this.pinned = false,
    this.floating = true,
    this.snap = true,
    this.leading,
    this.bottom,
    this.expandedHeight = 0,
    this.flexible,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Color backgroundColor;
  final bool pinned;
  final bool floating;
  final bool snap;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final double expandedHeight;
  final Widget? flexible;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerScrolled) => [
          SliverAppBar(
            title: Text(title),
            backgroundColor: backgroundColor,
            elevation: 0,
            pinned: pinned,
            floating: floating,
            snap: snap,
            leading: leading,
            actions: actions,
            bottom: bottom,
            expandedHeight: expandedHeight > 0 ? expandedHeight : null,
            flexibleSpace: flexible,
            automaticallyImplyLeading: automaticallyImplyLeading,
          ),
        ],
        body: body,
      ),
    );
  }
}
