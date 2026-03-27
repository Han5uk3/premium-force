import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/models/banner_model.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/common_widgets/button.dart';
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

  void _initializeBanners() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Create the default static banner
    _defaultBanner = BannerModel(
      id: 'default-banner',
      title:
          AppLocalizations.of(context)?.luxuryAirportTransfers ??
          'Luxury Airport Transfers',
      description:
          AppLocalizations.of(context)?.inSaudiArabia ?? 'In Saudi Arabia',
      imageUrl: 'assets/images/banner.png',
      isActive: true,
      createdAt: DateTime.now(),
    );

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

      if (kDebugMode) {
        debugPrint('🌐 API │ Banners Response: $response');
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
    if (!_pageController.hasClients || _banners.isEmpty) return;
    _pageController.jumpToPage(_infiniteBuffer);
    setState(() {
      _currentIndex = 0;
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_pageController.hasClients || _banners.isEmpty) return;

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
    // Initialize banners on first build
    if (!_isInitialized) {
      _initializeBanners();
    }

    if (_isLoading && _banners.isEmpty) {
      return Container(
        height: 140,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: PremiumLoader(color: Color(0xFFE4A46B), size: 24)),
      );
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
                physics: const BouncingScrollPhysics(),
                pageSnapping: true,
                onPageChanged: (int index) {
                  if (_banners.isEmpty) return;
                  final int realIndex = index % _banners.length;
                  setState(() {
                    _currentIndex = realIndex;
                  });
                  _startAutoScroll();
                },
                itemCount: 100000,
                itemBuilder: (context, index) {
                  final int bannerIndex = index % _banners.length;
                  final BannerModel banner = _banners[bannerIndex];

                  final Widget child = _buildBannerItem(
                    context,
                    banner,
                    bannerIndex == 0,
                  );

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, widget) {
                      double scale = 0.88;
                      if (_pageController.hasClients &&
                          _pageController.position.haveDimensions) {
                        final double page =
                            _pageController.page ??
                            _pageController.initialPage.toDouble();
                        final double diff = (page - index).abs();
                        scale = (1 - diff * 0.12).clamp(0.82, 1.0);
                      }
                      return Center(
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
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
    final isAsset = banner.imageUrl.startsWith('assets/');

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isAsset)
              Image.asset(banner.imageUrl, fit: BoxFit.cover)
            else
              CachedNetworkImage(
                imageUrl: banner.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[800]),
                errorWidget: (context, url, error) =>
                    Container(color: Colors.grey[800]),
                imageBuilder: (context, imageProvider) {
                  return Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
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
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF49280B).withAlpha(200),
            const Color(0xFF49280B).withAlpha(180),
            const Color(0xFF49280B).withAlpha(150),
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
          ],
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            banner.description,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isFirstCard) ...[
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: true,
              child: SizedBox(
                width: 90,
                height: 26,
                child: PremiumButton(
                  showLoader: false,
                  borderRadius: 18,
                  textColor: Colors.white,
                  text: AppLocalizations.of(context)?.bookNow ?? 'Book Now',
                  onTap: () {},
                  fontsize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
