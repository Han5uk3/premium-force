import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
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
  String? _promoSuccessText;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.username;
      _emailController.text = user.email;
      _phoneController.text = '${user.countryCode} ${user.phoneNumber}';
      _locationController.text = user.location ?? '';
      _specialIdController.text = user.specialId ?? '';
      _latitude = user.lat;
      _longitude = user.long;
      _isCorporateEmployee =
          user.specialId != null && user.specialId!.isNotEmpty;
      if (_isCorporateEmployee) {
        _initialPromoCode = user.specialId;
        _isPromoValid = true;
      }
    }

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

  @override
  void dispose() {
    _overlayEntry?.remove();
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
    _overlayEntry?.remove();
    _overlayEntry = null;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: AnimatedSnackBar(
            message: message,
            type: type,
            onDismissed: () {
              if (mounted) {
                _overlayEntry?.remove();
                _overlayEntry = null;
              }
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3E230A), Color(0xFF141313)],
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
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(thickness: 1),
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
                  child: Icon(icon, color: const Color(0xFFE4A46B), size: 30),
                ),
              ),

              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
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
          _promoSuccessText = promo['text'] ?? "Promo code applied successfully!";
        });
        if (mounted) {
          _showCustomSnackBar(AppLocalizations.of(context)!.promoCodeAppliedSuccessfully, type: "S");
        }
      } else {
        setState(() {
          _isPromoValid = false;
          _appliedPromoId = null;
          _promoSuccessText = null;
        });
        if (mounted) {
          _showCustomSnackBar(AppLocalizations.of(context)!.invalidPromoCode, type: "E");
        }
      }
    } else {
      if (mounted) {
        _showCustomSnackBar(
          result['message'] ?? AppLocalizations.of(context)!.invalidOrInactivePromoCode,
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
    _showCustomSnackBar(AppLocalizations.of(context)!.promoCodeRemoved, type: "W");
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isLoading = true);

    final token = UserLocalStorage.getToken();

    // Only include special ID if corporate employee is checked and promo is valid
    final specialId = (_isCorporateEmployee && _isPromoValid)
        ? _specialIdController.text.trim()
        : null;

    final result = await ApiService().updateUser(
      id: user.uid,
      username: _nameController.text.trim(),
      email: _emailController.text.trim(),
      location: _locationController.text.trim(),
      lat: _latitude,
      long: _longitude,
      profileImage: _profileImage,
      specialId: specialId,
      token: token,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      // Only increment if it's a NEW promo code compared to what was there initially
      final currentPromo = _specialIdController.text.trim();
      final hasNewPromo =
          _isPromoValid &&
          currentPromo.isNotEmpty &&
          currentPromo != _initialPromoCode;

      if (hasNewPromo && _appliedPromoId != null) {
        await ApiService().incrementSpecialContentCount(
          id: _appliedPromoId!,
          token: token,
        );
      }
      _showCustomSnackBar(AppLocalizations.of(context)!.profileUpdatedSuccessfully, type: "S");
      // Fetch user again to sync with provider
      await Provider.of<AuthProvider>(context, listen: false).fetchUser();

      if (!mounted) return;
      Navigator.pop(context);
    } else {
      _showCustomSnackBar(
        result['message'] as String? ?? AppLocalizations.of(context)!.updateFailed,
        type: "E",
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

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
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF49280B),
                                        Color(0xFFE4A46B),
                                        Color(0xFF60350F),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 112,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF0D0A08),
                                      ),
                                      child: _profileImage != null
                                          ? ClipOval(
                                              child: Image.file(
                                                _profileImage!,
                                                width: 112,
                                                height: 112,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : (user?.profileImageUrl != null &&
                                                user!
                                                    .profileImageUrl!
                                                    .isNotEmpty)
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl: user.profileImageUrl!,
                                                width: 112,
                                                height: 112,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                      child: PremiumLoader(
                                                        color: Color(
                                                          0xFFE4A46B,
                                                        ),
                                                      ),
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
                                // Camera edit icon
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF49280B),
                                          Color(0xFFE4A46B),
                                          Color(0xFF60350F),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(100),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.black,
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
                            AppLocalizations.of(context)!.tapToAddPhotoOptional,
                            style: TextStyle(
                              color: Colors.white.withAlpha(100),
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
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF49280B),
                                  Color(0xFFE4A46B),
                                  Color(0xFF60350F),
                                ],
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
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF49280B),
                                  Color(0xFFE4A46B),
                                  Color(0xFF60350F),
                                ],
                              ).createShader(bounds);
                            },
                            child: const Icon(
                              Icons.phone_outlined,
                              color: Colors.white,
                              size: 20,
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
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF49280B),
                                  Color(0xFFE4A46B),
                                  Color(0xFF60350F),
                                ],
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
                              color: Colors.white.withAlpha(60),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF0D0A08),
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
                                          ? const Color(0xFFE4A46B)
                                          : Colors.white.withAlpha(100),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    color: _isCorporateEmployee
                                        ? const Color(0xFFE4A46B)
                                        : Colors.transparent,
                                  ),
                                  child: _isCorporateEmployee
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Color(0xFF0D0A08),
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
                                  style: const TextStyle(
                                    color: Colors.white,
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
                            hintText: 'Enter your company email',
                            fontsize: 13,
                            needTitle: true,
                            obscureText: false,
                            readOnly: _isPromoValid,
                            enabled: !_isPromoValid,
                            prefixIcon: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  colors: [
                                    Color(0xFF49280B),
                                    Color(0xFFE4A46B),
                                    Color(0xFF60350F),
                                  ],
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
                                      return const LinearGradient(
                                        colors: [
                                          Color(0xFF49280B),
                                          Color(0xFFE4A46B),
                                          Color(0xFF60350F),
                                        ],
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
                                          ? AppLocalizations.of(context)!.remove
                                          : AppLocalizations.of(context)!.apply,
                                      gradient: _isPromoValid
                                          ? [
                                              Colors.red.shade800,
                                              Colors.red.shade400,
                                            ]
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
                                color: Colors.green.withAlpha(30),
                                border: Border.all(
                                  color: Colors.green.shade400,
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
                                        color: Colors.green.shade400,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _promoSuccessText ?? 'Promo code applied successfully!',
                                          style: TextStyle(
                                            color: Colors.green.shade300,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(color: Colors.white24, height: 1),
                                  const SizedBox(height: 8),
                                  _buildStatusRow(user?.isDiscountApproved),
                                ],
                              ),
                            ),
                          ],
                        ],

                        const SizedBox(height: 36),

                        // Save Changes button
                        PremiumButton(
                          showLoader: _isLoading,
                          fontsize: 16,
                          text: AppLocalizations.of(context)!.saveChanges,
                          onTap: _isLoading ? () {} : _handleUpdateProfile,
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Loading overlay
            if (_isLoading) const PremiumLoaderOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String? status) {
    String label = "Verification Pending";
    Color color = Colors.orange.shade400;
    IconData icon = Icons.hourglass_empty;

    // If the promo code has changed, it's pending until profile is saved and reviewed
    final currentCode = _specialIdController.text.trim();
    if (currentCode != _initialPromoCode) {
      label = "Verification Pending";
    } else {
      switch (status?.toLowerCase()) {
        case 'approved':
          label = "Discount Approved";
          color = Colors.green.shade400;
          icon = Icons.verified;
          break;
        case 'rejected':
          label = "Discount Rejected";
          color = Colors.red.shade400;
          icon = Icons.cancel;
          break;
        default:
          label = "Verification Pending";
          color = Colors.orange.shade400;
          icon = Icons.hourglass_empty;
      }
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          "Status: ",
          style: TextStyle(
            color: Colors.white70,
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
    return Center(
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            colors: [Color(0xFF49280B), Color(0xFFE4A46B), Color(0xFF60350F)],
          ).createShader(bounds);
        },
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 48),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(150), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.manageProfile,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}
