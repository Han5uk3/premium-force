import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/api/user_api_v2.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ManageProfilePage extends StatefulWidget {
  const ManageProfilePage({super.key});

  @override
  State<ManageProfilePage> createState() => _ManageProfilePageState();
}

class _ManageProfilePageState extends State<ManageProfilePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _specialIdController = TextEditingController();
  final TextEditingController _companyEmailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  File? _profileImage;
  double? _latitude;
  double? _longitude;
  bool _isCorporateEmployee = false;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _isCheckingPromo = false;
  bool _isPromoValid = false;
  String? _appliedPromoId;
  String? _initialPromoCode;

  // Snapshot of what the page loaded with. Used to skip the save entirely when
  // nothing was edited, and to leave an unchanged special id out of the request.
  String _initialName = '';
  String _initialEmail = '';
  String _initialLocation = '';
  double? _initialLat;
  double? _initialLong;
  String? _promoSuccessText;

  @override
  void initState() {
    super.initState();

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) _applyUser(user);

    // The cached user fills the form immediately; the server's copy replaces it
    // as soon as it arrives.
    _refreshProfile();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    );
    _animController.forward();
  }

  /// Fill the form from [user] and re-take the snapshot the save compares
  /// against, so a field that only changed because the server said so is not
  /// counted as an edit.
  void _applyUser(UserModel user) {
    _nameController.text = user.username;
    _emailController.text = user.email;
    _phoneController.text = '${user.countryCode} ${user.phoneNumber}';
    _locationController.text = user.location ?? '';
    _specialIdController.text = user.specialId ?? '';
    _latitude = user.lat;
    _longitude = user.long;
    _isCorporateEmployee = user.specialId != null && user.specialId!.isNotEmpty;
    if (_isCorporateEmployee) {
      _companyEmailController.text = user.companyEmail ?? '';
      _initialPromoCode = user.specialId;
      _isPromoValid = true;
    }

    _initialName = _nameController.text.trim();
    _initialEmail = _emailController.text.trim();
    _initialLocation = _locationController.text.trim();
    _initialLat = _latitude;
    _initialLong = _longitude;
  }

  /// Re-read the profile from `GET /api/v2/user/me` when the page opens.
  ///
  /// The cached user the page was built from can be stale — it is whatever the
  /// last fetch or save left in Hive — so the server is asked for the current
  /// record and the rest of the app is put on it too.
  ///
  /// A failure is left silent: the form is already usable from the cache, and
  /// an error banner over a page the customer opened to edit would be noise.
  /// The reason is on the log either way.
  ///
  /// Anything already typed wins: the response is only applied while the form
  /// still matches what it loaded with, so a slow reply cannot overwrite an
  /// edit in progress.
  Future<void> _refreshProfile() async {
    final result = await UserApiV2().getProfile();
    final user = result.data;
    if (!mounted || user == null) return;

    await context.read<AuthProvider>().updateUser(user);
    if (!mounted || _hasUnsavedChanges) return;

    setState(() => _applyUser(user));
  }

  @override
  void dispose() {
    AnimatedSnackBar.dismiss();
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _specialIdController.dispose();
    _companyEmailController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message, {String type = "E"}) {
    AnimatedSnackBar.show(context, message, type);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: c.sheetGradient,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.chooseProfilePicture,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close, color: c.icon),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: c.divider, thickness: 1),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildImageSourceOption(
                            icon: Icons.camera_alt_rounded,
                            label: loc.camera,
                            onTap: () async {
                              Navigator.pop(context);
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.camera,
                                maxWidth: 800,
                                maxHeight: 800,
                                imageQuality: 85,
                              );
                              if (image != null) {
                                setState(() {
                                  _profileImage = File(image.path);
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildImageSourceOption(
                            icon: Icons.photo_library_rounded,
                            label: loc.gallery,
                            onTap: () async {
                              Navigator.pop(context);
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 800,
                                maxHeight: 800,
                                imageQuality: 85,
                              );
                              if (image != null) {
                                setState(() {
                                  _profileImage = File(image.path);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: PremiumContainer(
        height: 115,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Icon(icon, color: c.accent, size: 30),
                ),
              ),

              Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPromoCode() async {
    final code = _specialIdController.text.trim();
    final companyEmail = _companyEmailController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isCheckingPromo = true;
      _isPromoValid = false;
      _appliedPromoId = null;
    });

    final result = await ApiService().validatePromoCode(
      code: code,
      companyEmail: _isCorporateEmployee ? companyEmail : null,
    );

    if (result['success'] == true) {
      final promo = result['data'];
      if (promo != null) {
        setState(() {
          _isPromoValid = true;
          _appliedPromoId = promo['code'] ?? code;
          _promoSuccessText =
              promo['text'] ??
              AppLocalizations.of(context)!.promoCodeAppliedSuccessfully;
        });
        if (mounted) {
          _showCustomSnackBar(
            AppLocalizations.of(context)!.promoCodeAppliedSuccessfully,
            type: "S",
          );
        }
      } else {
        setState(() {
          _isPromoValid = false;
          _appliedPromoId = null;
          _promoSuccessText = null;
        });
        if (mounted) {
          _showCustomSnackBar(
            AppLocalizations.of(context)!.invalidPromoCode,
            type: "E",
          );
        }
      }
    } else {
      if (mounted) {
        _showCustomSnackBar(
          result['message'] ??
              AppLocalizations.of(context)!.invalidOrInactivePromoCode,
          type: "E",
        );
      }
    }

    setState(() => _isCheckingPromo = false);
  }

  void _removePromoCode() {
    setState(() {
      _isPromoValid = false;
      _appliedPromoId = null;
      _promoSuccessText = null;
      _specialIdController.clear();
    });
    _showCustomSnackBar(
      AppLocalizations.of(context)!.promoCodeRemoved,
      type: "W",
    );
  }

  /// The special id to send, or null to leave the stored one untouched.
  ///
  /// The backend rejects a specialId it already holds ("User already has a
  /// special ID"), and that 400 fails the entire update — so re-sending the
  /// loaded value would block saving a name or photo change too. Only a
  /// genuinely new code goes on the wire; [ApiService.updateUser] omits nulls.
  String? get _changedSpecialId {
    if (!_isCorporateEmployee || !_isPromoValid) return null;
    final current = _specialIdController.text.trim();
    if (current.isEmpty || current == _initialPromoCode) return null;
    return current;
  }

  /// Whether any field differs from what the page loaded with.
  bool get _hasUnsavedChanges =>
      _profileImage != null ||
      _nameController.text.trim() != _initialName ||
      _emailController.text.trim() != _initialEmail ||
      _locationController.text.trim() != _initialLocation ||
      _latitude != _initialLat ||
      _longitude != _initialLong ||
      _changedSpecialId != null;

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    // The Save button stays greyed out until something changes, so this only
    // guards against a programmatic call.
    if (!_hasUnsavedChanges) return;

    setState(() => _isLoading = true);

    final token = UserLocalStorage.getToken();

    final result = await ApiService().updateUser(
      id: user.uid,
      username: _nameController.text.trim(),
      email: _emailController.text.trim(),
      location: _locationController.text.trim(),
      lat: _latitude,
      long: _longitude,
      profileImage: _profileImage,
      specialId: _changedSpecialId,
      token: token,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      // Only increment for a genuinely new promo code — same condition that
      // decided whether to send it at all.
      if (_changedSpecialId != null && _appliedPromoId != null) {
        await ApiService().incrementSpecialContentCount(
          id: _appliedPromoId!,
          token: token,
        );
      }
      _showCustomSnackBar(
        AppLocalizations.of(context)!.profileUpdatedSuccessfully,
        type: "S",
      );
      // Fetch user again to sync with provider
      await Provider.of<AuthProvider>(context, listen: false).fetchUser();

      if (!mounted) return;
      Navigator.pop(context);
    } else {
      _showCustomSnackBar(
        result['message'] as String? ??
            AppLocalizations.of(context)!.updateFailed,
        type: "E",
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: c.pageGradient,
        ),
      ),
      child: PopScope(
        // Keep the user on the page while the save is in flight. This covers
        // the system back gesture and the hardware back button; the app bar's
        // own back button is disabled separately in [_buildAppBar].
        canPop: !_isLoading,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(),
          body: Stack(
            children: [
              AbsorbPointer(
                absorbing: _isLoading,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),

                          // Profile Picture
                          Center(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  // Gradient border
                                  Container(
                                    width: 116,
                                    height: 116,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: c.goldGradient,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 112,
                                        height: 112,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: c.surfaceDeep,
                                        ),
                                        child: _profileImage != null
                                            ? ClipOval(
                                                child: Image.file(
                                                  _profileImage!,
                                                  width: 112,
                                                  height: 112,
                                                  fit: BoxFit.cover,
                                                  // Camera/gallery pick can be
                                                  // 800px wide; the avatar is
                                                  // 112pt. Decode downsampled.
                                                  cacheWidth: 336,
                                                ),
                                              )
                                            : (user?.profileImageUrl != null &&
                                                  user!
                                                      .profileImageUrl!
                                                      .isNotEmpty)
                                            ? ClipOval(
                                                child: CachedNetworkImage(
                                                  imageUrl:
                                                      user.profileImageUrl!,
                                                  width: 112,
                                                  height: 112,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: 336,
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                        child: PremiumLoader(),
                                                      ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          _buildPlaceholderIcon(),
                                                ),
                                              )
                                            : _buildPlaceholderIcon(),
                                      ),
                                    ),
                                  ),
                                  // Camera edit icon, on the trailing side of the
                                  // avatar so it flips to the left in RTL.
                                  PositionedDirectional(
                                    bottom: 2,
                                    end: 2,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: c.goldGradient,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: c.shadow,
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        color: c.onGold,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.tapToAddPhotoOptional,
                              style: TextStyle(
                                color: c.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Name field
                          PremiumTextField(
                            title: AppLocalizations.of(context)!.fullName,
                            controller: _nameController,
                            hintText: AppLocalizations.of(
                              context,
                            )!.enterYourFullName,
                            fontsize: 13,
                            keyboardType: TextInputType.name,
                            needTitle: true,
                            obscureText: false,
                            prefixIcon: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  colors: c.goldIconGradient,
                                ).createShader(bounds);
                              },
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                )!.pleaseEnterYourName;
                              }
                              if (value.length < 2) {
                                return AppLocalizations.of(
                                  context,
                                )!.nameMustBeAtLeast2Characters;
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // Phone number (display only)
                          PremiumTextField(
                            isPhoneNumber: true,
                            ltrValueOnly: true,
                            title: AppLocalizations.of(context)!.phoneNumber,
                            controller: _phoneController,
                            hintText: "",
                            fontsize: 13,
                            needTitle: true,
                            obscureText: false,
                            enabled: false,
                            readOnly: true,
                            prefixIcon: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  colors: c.goldIconGradient,
                                ).createShader(bounds);
                              },
                              // The handset glyph leans to one side, so mirror it
                              // in RTL to sit with the flipped layout. Only the
                              // icon flips; the gradient keeps its direction.
                              child: Transform.scale(
                                scaleX:
                                    Directionality.of(context) ==
                                        TextDirection.rtl
                                    ? -1
                                    : 1,
                                child: const Icon(
                                  Icons.phone_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Email field
                          PremiumTextField(
                            title: AppLocalizations.of(context)!.emailAddress,
                            controller: _emailController,
                            hintText: AppLocalizations.of(
                              context,
                            )!.enterYourEmailAddress,
                            fontsize: 13,
                            keyboardType: TextInputType.emailAddress,
                            needTitle: true,
                            obscureText: false,
                            enabled: false,
                            readOnly: true,
                            prefixIcon: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  colors: c.goldIconGradient,
                                ).createShader(bounds);
                              },
                              child: const Icon(
                                Icons.email_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Location field (tap to open location picker)
                          // _buildLocationField(),
                          // const SizedBox(height: 20),

                          // Corporate Employee Toggle
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: c.border,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: c.surfaceDeep,
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isCorporateEmployee =
                                          !_isCorporateEmployee;
                                    });
                                  },
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _isCorporateEmployee
                                            ? c.accent
                                            : c.borderStrong,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color: _isCorporateEmployee
                                          ? c.accent
                                          : Colors.transparent,
                                    ),
                                    child: _isCorporateEmployee
                                        ? Icon(
                                            Icons.check,
                                            size: 14,
                                            color: c.onAccent,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.iAmACorporateEmployee,
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_isCorporateEmployee) ...[
                            const SizedBox(height: 20),
                            // Company Email field
                            PremiumTextField(
                              title: AppLocalizations.of(context)!.companyEmail,
                              controller: _companyEmailController,
                              hintText: AppLocalizations.of(
                                context,
                              )!.enterYourCompanyEmail,
                              fontsize: 13,
                              needTitle: true,
                              obscureText: false,
                              readOnly: _isPromoValid,
                              enabled: !_isPromoValid,
                              prefixIcon: ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return LinearGradient(
                                    colors: c.goldIconGradient,
                                  ).createShader(bounds);
                                },
                                child: const Icon(
                                  Icons.email_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Promo Code field
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: PremiumTextField(
                                    title: AppLocalizations.of(
                                      context,
                                    )!.promoCode,
                                    controller: _specialIdController,
                                    hintText: AppLocalizations.of(
                                      context,
                                    )!.enterYourPromoCode,
                                    fontsize: 13,
                                    needTitle: true,
                                    obscureText: false,
                                    readOnly: _isPromoValid,
                                    enabled: !_isPromoValid,
                                    prefixIcon: ShaderMask(
                                      shaderCallback: (Rect bounds) {
                                        return LinearGradient(
                                          colors: c.goldIconGradient,
                                        ).createShader(bounds);
                                      },
                                      child: const Icon(
                                        Icons.badge_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (_isCorporateEmployee &&
                                          (value == null || value.isEmpty)) {
                                        return AppLocalizations.of(
                                          context,
                                        )!.pleaseEnterYourPromoCode;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 0),
                                    child: SizedBox(
                                      height: 59,
                                      child: PremiumButton(
                                        showLoader: _isCheckingPromo,
                                        fontsize: 12,
                                        text: _isPromoValid
                                            ? AppLocalizations.of(
                                                context,
                                              )!.remove
                                            : AppLocalizations.of(
                                                context,
                                              )!.apply,
                                        // Destructive, so it drops the gold for
                                        // the error tone.
                                        gradient: _isPromoValid
                                            ? [c.error, c.error]
                                            : null,
                                        onTap: _isCheckingPromo
                                            ? () {}
                                            : _isPromoValid
                                            ? _removePromoCode
                                            : _verifyPromoCode,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_isPromoValid) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: c.successSurface,
                                  border: Border.all(
                                    color: c.successBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: c.success,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _promoSuccessText ??
                                                AppLocalizations.of(
                                                  context,
                                                )!.promoCodeAppliedSuccessfully,
                                            style: TextStyle(
                                              color: c.success,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Divider(
                                      color: c.divider,
                                      height: 1,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildStatusRow(user?.isDiscountApproved),
                                  ],
                                ),
                              ),
                            ],
                          ],

                          const SizedBox(height: 36),

                          // Save Changes button. The text controllers don't
                          // rebuild the page on their own, so the button is
                          // rebuilt against them directly — otherwise it would
                          // stay greyed out until some other setState landed.
                          // The remaining inputs to [_hasUnsavedChanges]
                          // (photo, coordinates, promo flags) already go
                          // through setState.
                          ListenableBuilder(
                            listenable: Listenable.merge([
                              _nameController,
                              _emailController,
                              _locationController,
                              _specialIdController,
                            ]),
                            builder: (context, _) => PremiumButton(
                              showLoader: _isLoading,
                              enabled: _hasUnsavedChanges,
                              fontsize: 16,
                              text: AppLocalizations.of(context)!.saveChanges,
                              onTap: _handleUpdateProfile,
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // No full-screen loader here on purpose: the save indicator is the
              // black loader inside the Save Changes button. A scrim overlay
              // would cover that button and show a competing second spinner.
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String? status) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;

    String label = loc.verificationPending;
    Color color = c.warning;
    IconData icon = Icons.hourglass_empty;

    // If the promo code has changed, it's pending until profile is saved and reviewed
    final currentCode = _specialIdController.text.trim();
    if (currentCode != _initialPromoCode) {
      label = loc.verificationPending;
    } else {
      switch (status?.toLowerCase()) {
        case 'approved':
          label = loc.discountApproved;
          color = c.success;
          icon = Icons.verified;
          break;
        case 'rejected':
          label = loc.discountRejected;
          color = c.error;
          icon = Icons.cancel;
          break;
        default:
          label = loc.verificationPending;
          color = c.warning;
          icon = Icons.hourglass_empty;
      }
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          '${loc.status}: ',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderIcon() {
    final c = context.colors;
    return Center(
      child: ShaderMask(
        shaderCallback: (Rect bounds) =>
            LinearGradient(colors: c.goldIconGradient).createShader(bounds),
        // White, and it has to be: ShaderMask defaults to BlendMode.modulate,
        // which multiplies the child by the shader, and white is that
        // operation's identity.
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 48),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final c = context.colors;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: c.appBarScrim,
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.manageProfile,
            style: TextStyle(
              fontSize: 18,
              color: c.textPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              size: 16,
              // Dimmed while saving so the disabled state reads as deliberate.
              color: _isLoading ? c.textDisabled : c.icon,
            ),
            onPressed: _isLoading ? null : () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}
