import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1105),
            Color(0xFF1E1105),
            Color.fromARGB(255, 26, 23, 23),
            Color.fromARGB(255, 26, 23, 23),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buidAppBar(context),
        body: Column(
          children: [
            TabBar(
              controller: _tabController,
              dividerColor: Colors.grey.shade800,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              indicator: const _GradientTabIndicator(
                gradient: _tabGradient,
                height: 3.0,
              ),
              unselectedLabelColor: Colors.grey.shade800,
              tabs: [
                _GradientTab(
                  text: loc.upcoming,
                  controller: _tabController,
                  index: 0,
                  gradient: _tabGradient,
                ),
                _GradientTab(
                  text: loc.ongoing,
                  controller: _tabController,
                  index: 1,
                  gradient: _tabGradient,
                ),
                _GradientTab(
                  text: loc.completed,
                  controller: _tabController,
                  index: 2,
                  gradient: _tabGradient,
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Center(
                    child: Text(
                      loc.upcoming,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Center(
                    child: Text(
                      loc.completed,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Center(
                    child: Text(
                      loc.completed,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget buidAppBar(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(100), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            loc.bookings,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
      ),
    );
  }
}

const Gradient _tabGradient = LinearGradient(
  colors: [Color(0xFF49280B), Color(0xFFE4A46B), Color(0xFF60350F)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _GradientTabIndicator extends Decoration {
  final double height;
  final Gradient gradient;

  const _GradientTabIndicator({this.height = 3.0, required this.gradient});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientPainter(this, onChanged);
  }
}

class _GradientPainter extends BoxPainter {
  final _GradientTabIndicator decoration;

  _GradientPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect =
        Offset(
          offset.dx,
          (configuration.size?.height ?? 0) - decoration.height,
        ) &
        Size(configuration.size?.width ?? 0, decoration.height);
    final Paint paint = Paint()
      ..shader = decoration.gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }
}

class _GradientTab extends AnimatedWidget implements PreferredSizeWidget {
  final String text;
  final TabController controller;
  final int index;
  final Gradient gradient;

  _GradientTab({
    required this.text,
    required this.controller,
    required this.index,
    required this.gradient,
  }) : super(listenable: controller.animation!);

  @override
  Widget build(BuildContext context) {
    double animationValue = controller.animation?.value ?? index.toDouble();
    double isSelectedValue =
        1.0 - (animationValue - index).abs().clamp(0.0, 1.0);

    return Tab(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 1.0 - isSelectedValue,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          Opacity(
            opacity: isSelectedValue,
            child: ShaderMask(
              shaderCallback: (bounds) => gradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              blendMode: BlendMode.srcIn,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(46.0);
}
