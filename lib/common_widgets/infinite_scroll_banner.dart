import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/models/banner_model.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/common_widgets/button.dart';

/// Infinite scroll banner widget that displays banners one by one
class InfiniteScrollBanner extends StatefulWidget {
  const InfiniteScrollBanner({super.key});

  @override
  State<InfiniteScrollBanner> createState() => _InfiniteScrollBannerState();
}

class _InfiniteScrollBannerState extends State<InfiniteScrollBanner>
    with WidgetsBindingObserver {
  late PageController _pageController;
  List<BannerModel> _banners = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  // Static default banner shown on app open
  late BannerModel _defaultBanner;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
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
      final response = await api.getBanners();

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

        // Auto-scroll banners after a delay
        _startAutoScroll();
      } else {
        // If API fails, just use the default banner
        setState(() {
          _banners = [_defaultBanner];
          _isLoading = false;
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
        _startAutoScroll();
      }
    }
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _pageController.hasClients && _banners.isNotEmpty) {
        int nextPage = (_currentIndex + 1) % _banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resume auto-scroll when app comes back to foreground
      if (mounted && _banners.isNotEmpty) {
        _startAutoScroll();
      }
    }
  }

  @override
  void dispose() {
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

    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int index) {
              setState(() => _currentIndex = index);
              // Continue auto-scroll on manual scroll
              Future.delayed(const Duration(milliseconds: 100), () {
                _startAutoScroll();
              });
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              return _buildBannerItem(context, _banners[index]);
            },
          ),
          // Indicator dots at the bottom
          if (_banners.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
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
    );
  }

  Widget _buildBannerItem(BuildContext context, BannerModel banner) {
    final isAsset = banner.imageUrl.startsWith('assets/');

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        image: isAsset
            ? DecorationImage(
                image: AssetImage(banner.imageUrl),
                fit: BoxFit.cover,
              )
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isAsset
          ? _buildBannerOverlay(context, banner)
          : CachedNetworkImage(
              imageUrl: banner.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[800]),
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
                  child: _buildBannerOverlay(context, banner),
                );
              },
            ),
    );
  }

  Widget _buildBannerOverlay(BuildContext context, BannerModel banner) {
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
      ),
    );
  }
}
