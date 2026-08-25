import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/models/banner_model.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

/// Infinite scroll banner widget that displays banners one by one
class InfiniteScrollBanner extends StatefulWidget {
  const InfiniteScrollBanner({super.key});

  @override
  State<InfiniteScrollBanner> createState() => _InfiniteScrollBannerState();
}

class _InfiniteScrollBannerState extends State<InfiniteScrollBanner>
    with WidgetsBindingObserver {
  static const int _infiniteBuffer = 10000;

  late PageController _pageController;
  List<BannerModel> _banners = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  bool _isInitialized = false;

  // Timer for continuous auto-scroll
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(
      viewportFraction: 0.8,
      initialPage: _infiniteBuffer,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update localizations whenever dependencies change (e.g., locale change)
    if (!_isInitialized) {
      _initializeBanners();
    }
  }

  void _initializeBanners() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Fetch banners from the backend
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    try {
      if (!mounted) return;

      setState(() => _isLoading = true);

      final api = ApiService();
      final token = UserLocalStorage.getToken();
      final response = await api.getBanners(token: token);

      if (!mounted) return;

      if (response['success'] == true) {
        final rawData = response['data'] ?? response['banners'] ?? [];

        List<BannerModel> fetchedBanners = [];
        if (rawData is List) {
          fetchedBanners = rawData
              .map((item) => BannerModel.fromJson(item as Map<String, dynamic>))
              .where((banner) => banner.isActive)
              .toList();
        }

        // Use only fetched banners
        setState(() {
          _banners = fetchedBanners;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToInitialPage();
        });

        // Auto-scroll banners after a delay
        _startAutoScroll();
      } else {
        // If API fails, show nothing or empty state
        setState(() {
          _banners = [];
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToInitialPage();
        });
        _startAutoScroll();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _banners = [];
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToInitialPage();
        });
        _startAutoScroll();
      }
    }
  }

  void _jumpToInitialPage() {
    if (!_pageController.hasClients || _banners.length <= 1) return;

    // Only jump if we are not already at the buffer or if specifically requested
    try {
      final double currentPage = _pageController.page ?? 0.0;
      if (currentPage == 0.0 || (currentPage - _infiniteBuffer).abs() > 0.5) {
        _pageController.jumpToPage(_infiniteBuffer);
      }
    } catch (_) {
      _pageController.jumpToPage(_infiniteBuffer);
    }

    if (mounted) {
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_pageController.hasClients || _banners.length <= 1)
        return;

      int current = _pageController.page?.round() ?? _infiniteBuffer;
      int nextPage = current + 1;

      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resume auto-scroll when app comes back to foreground
      if (mounted && _banners.isNotEmpty) {
        _startAutoScroll();
      }
    } else if (state == AppLifecycleState.paused) {
      // Pause auto-scroll when app goes to background
      _autoScrollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _banners.isEmpty) {
      return _buildShimmerLoading(context);
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final c = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 2.5, // width / height = 2.5
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                physics: _banners.length > 1
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                pageSnapping: true,

                onPageChanged: (int index) {
                  if (_banners.isEmpty) return;
                  final int realIndex = index % _banners.length;
                  setState(() {
                    _currentIndex = realIndex;
                  });
                  _startAutoScroll();
                },
                itemCount: _banners.length == 1 ? 1 : 100000,
                itemBuilder: (context, index) {
                  final int bannerIndex = _banners.length == 1
                      ? 0
                      : index % _banners.length;
                  final BannerModel banner = _banners[bannerIndex];

                  final Widget child = _buildBannerItem(context, banner);

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, widget) {
                      double scale =
                          1.0; // Default to full size instead of 0.88 to avoid shrinking

                      if (_pageController.hasClients) {
                        try {
                          // Try to get current page, fallback to a sensible default if null
                          final double page =
                              _pageController.page ??
                              _infiniteBuffer.toDouble();
                          final double diff = (page - index).abs();
                          scale = (1 - diff * 0.12).clamp(0.82, 1.0);
                        } catch (_) {
                          // If page cannot be read, stay at 1.0 or based on index relative to buffer
                          if (index == _infiniteBuffer)
                            scale = 1.0;
                          else
                            scale = 0.82;
                        }
                      } else {
                        // If not yet attached, we assume the first active page (index == initialPage) is full size
                        if (index == _infiniteBuffer)
                          scale = 1.0;
                        else
                          scale = 0.82;
                      }

                      return Center(
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: c.shadow,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: widget,
                          ),
                        ),
                      );
                    },
                    child: child,
                  );
                },
              ),
            ],
          ),
        ),
        // Indicator dots below the banner
        if (_banners.length > 1)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _banners.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // The dots sit under the banner, on the page — not on
                        // the artwork — so they take the page's ink.
                        color: _currentIndex == index
                            ? c.textPrimary
                            : c.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBannerItem(BuildContext context, BannerModel banner) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      // The deep-gold ground shows only where the artwork does not reach, and
      // while it loads — so it is the same warm tone in both modes rather than
      // a surface colour, which would read as a hole in the carousel.
      child: Container(
        color: c.accentDeep,
        width: double.infinity,
        height: double.infinity,
        child: CachedNetworkImage(
          key: ValueKey(Localizations.localeOf(context).languageCode),
          imageUrl:
              (Localizations.localeOf(context).languageCode == 'ar' &&
                  banner.imageUrlAr.isNotEmpty)
              ? banner.imageUrlAr
              : banner.imageUrl,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          // Full-bleed banner: cap decode at ~1080px wide regardless of the
          // source asset size, which is plenty for any phone screen.
          memCacheWidth: 1080,
          placeholder: (context, url) =>
              Container(color: c.accentDeep.withAlpha(100)),
          errorWidget: (context, url, error) =>
              Container(color: c.accentDeep.withAlpha(100)),
          imageBuilder: (context, imageProvider) {
            return Container(
              decoration: BoxDecoration(
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final c = context.colors;
    // The white blocks below are alpha stencils: Shimmer masks its child with
    // `BlendMode.srcIn`, so these two colours are the only ones painted.
    return Shimmer.fromColors(
      baseColor: c.shimmerBase,
      highlightColor: c.shimmerHighlight,
      child: AspectRatio(
        aspectRatio: 2.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center shimmer card
            Container(
              width: width * 0.8,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Left peek card
            Positioned(
              left: -(width * 0.7), // Shows 10% of the 80% width card
              child: Transform.scale(
                scale: 0.88,
                child: Container(
                  width: width * 0.8,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            // Right peek card
            Positioned(
              right: -(width * 0.7), // Shows 10% of the 80% width card
              child: Transform.scale(
                scale: 0.88,
                child: Container(
                  width: width * 0.8,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
