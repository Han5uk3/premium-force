import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/models/banner_model.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/common_widgets/button.dart';
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

  // Static default banner shown on app open
  late BannerModel _defaultBanner;
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
    if (_isInitialized) {
      _updateDefaultBanner();
    } else {
      _initializeBanners();
    }
  }

  void _initializeBanners() {
    if (_isInitialized) return;
    _isInitialized = true;

    _updateDefaultBanner();

    // Fetch banners from the backend
    _fetchBanners();
  }

  void _updateDefaultBanner() {
    // Create or update the default static banner with current localized strings
    final loc = AppLocalizations.of(context);
    final String title =
        loc?.luxuryAirportTransfers ?? 'Luxury Airport Transfers';
    final String description = loc?.inSaudiArabia ?? 'In Saudi Arabia';

    _defaultBanner = BannerModel(
      id: 'default-banner',
      title: title,
      description: description,
      imageUrl: 'assets/images/banner.png',
      isActive: true,
      createdAt: _isInitialized && _banners.isNotEmpty
          ? _defaultBanner.createdAt
          : DateTime.now(),
    );

    // If banners list is already populated, update the default banner in the list
    if (_banners.isNotEmpty) {
      final int index = _banners.indexWhere((b) => b.id == 'default-banner');
      if (index != -1) {
        setState(() {
          _banners[index] = _defaultBanner;
        });
      }
    }
  }

  Future<void> _fetchBanners() async {
    try {
      if (!mounted) return;

      setState(() => _isLoading = true);

      final api = ApiService();
      final token = UserLocalStorage.getToken();
      final response = await api.getBanners(token: token);

      if (kDebugMode) {
        debugPrint('ðŸŒ API â”‚ Banners Response: $response');
      }

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

        // Combine default banner with fetched banners
        setState(() {
          _banners = [_defaultBanner, ...fetchedBanners];
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToInitialPage();
        });

        // Auto-scroll banners after a delay
        _startAutoScroll();
      } else {
        // If API fails, just use the default banner
        setState(() {
          _banners = [_defaultBanner];
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToInitialPage();
        });
        _startAutoScroll();
      }
    } catch (e) {
      debugPrint('Error fetching banners: $e');
      if (mounted) {
        setState(() {
          _banners = [_defaultBanner];
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 140,
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

                  final Widget child = _buildBannerItem(
                    context,
                    banner,
                    bannerIndex == 0,
                  );

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
                                  color: Colors.black.withAlpha(
                                    64,
                                  ), // Using alpha for stability
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
                        color: _currentIndex == index
                            ? Colors.white
                            : Colors.white.withAlpha(128),
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

  Widget _buildBannerItem(
    BuildContext context,
    BannerModel banner,
    bool isFirstCard,
  ) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final alignment =
        Alignment.centerRight; // Fixed alignment, let Transform handle the flip
    final begin = isRtl ? Alignment.centerRight : Alignment.centerLeft;
    final end = isRtl ? Alignment.centerLeft : Alignment.centerRight;

    final isAsset = banner.imageUrl.startsWith('assets/');

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFF49280B),
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isAsset)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: begin,
                    end: end,
                    colors: const [Color(0xFF49280B), Color(0xff1A1A1A)],
                    stops: [0.0, 0.8],
                  ),
                ),
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: begin,
                      end: end,
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.1),
                        Colors.white,
                      ],
                      stops: const [0.0, 0.3, 0.7],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Transform.flip(
                    flipX: isRtl,
                    child: Image.asset(
                      banner.imageUrl,
                      fit: BoxFit.contain,
                      alignment: alignment,
                    ),
                  ),
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: banner.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFF49280B).withAlpha(100)),
                errorWidget: (context, url, error) =>
                    Container(color: const Color(0xFF49280B).withAlpha(100)),
                imageBuilder: (context, imageProvider) {
                  return Transform.flip(
                    flipX: isRtl,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            _buildBannerOverlay(context, banner, isFirstCard),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerOverlay(
    BuildContext context,
    BannerModel banner,
    bool isFirstCard,
  ) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final begin = isRtl ? Alignment.centerRight : Alignment.centerLeft;
    final end = isRtl ? Alignment.centerLeft : Alignment.centerRight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            const Color(0xFF49280B),
            const Color(0xFF49280B).withOpacity(0.8),
            const Color(0xFF49280B).withOpacity(0.0),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.8, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            banner.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            banner.description,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: SizedBox(
        height: 140,
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

