import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/authentication/location_picker.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/home/home.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';

class SignUpPage extends StatefulWidget {
  final String countryCode;
  final String phoneNumber;
  const SignUpPage({
    super.key,
    required this.countryCode,
    required this.phoneNumber,
  });

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _specialIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  File? _profileImage;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.phoneNumber;
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
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _specialIdController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
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
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loc.chooseProfilePicture,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImageSourceOption(
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
                      _buildImageSourceOption(
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
                    ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF49280B),
                  Color(0xFFE4A46B),
                  Color(0xFF60350F),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0A08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: const Color(0xFFE4A46B), size: 30),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(
      context,
    ).push(SmoothNavigation.route(const LocationPickerPage()));

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _locationController.text = result['address'] ?? '';
        _latitude = result['lat'] as double?;
        _longitude = result['lng'] as double?;
      });
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_profileImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseAddAProfilePicture),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectYourLocation),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService().createUser(
      username: _nameController.text.trim(),
      email: _emailController.text.trim(),
      countryCode: widget.countryCode,
      phoneNumber: widget.phoneNumber,
      location: _locationController.text.trim(),
      lat: _latitude,
      long: _longitude,
      profileImage: _profileImage,
      specialId: _specialIdController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Save user data to local storage
      final userData = result['data'] as Map<String, dynamic>?;
      if (userData != null) {
        final user = UserModel.fromJson(userData);
        await UserLocalStorage.saveUser(user);

        // Save token if returned
        final token = result['token'] as String?;
        if (token != null) {
          await UserLocalStorage.saveToken(token);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Home()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? 'Signup failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                                          : Center(
                                              child: ShaderMask(
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
                                                  Icons.person_rounded,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                              ),
                                            ),
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
                            AppLocalizations.of(context)!.tapToAddPhoto,
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
                          fontsize: 15,
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
                          title: AppLocalizations.of(context)!.phoneNumber,
                          controller: _phoneController,
                          hintText: widget.phoneNumber,
                          fontsize: 15,
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
                          fontsize: 15,
                          keyboardType: TextInputType.emailAddress,
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
                              Icons.email_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(
                                context,
                              )!.pleaseEnterYourEmail;
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return AppLocalizations.of(
                                context,
                              )!.pleaseEnterAValidEmail;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Location field (tap to open location picker)
                        _buildLocationField(),

                        const SizedBox(height: 20),

                        // Special ID (optional)
                        PremiumTextField(
                          title: AppLocalizations.of(
                            context,
                          )!.specialidoptional,
                          controller: _specialIdController,
                          hintText: AppLocalizations.of(
                            context,
                          )!.enterSpecialIdIFAvailable,
                          fontsize: 15,
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
                              Icons.badge_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Sign Up button
                        PremiumButton(
                          showLoader: _isLoading,
                          fontsize: 18,
                          text: AppLocalizations.of(context)!.createAccount,
                          onTap: _isLoading ? () {} : _handleSignUp,
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

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)!.location,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openLocationPicker,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0A08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1A1410), width: 1),
            ),
            child: Row(
              children: [
                ShaderMask(
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
                    Icons.location_on_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _locationController.text.isEmpty
                        ? AppLocalizations.of(context)!.tapToSelectYourLocation
                        : _locationController.text,
                    style: TextStyle(
                      color: _locationController.text.isEmpty
                          ? Colors.white.withAlpha(180)
                          : Colors.white,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ShaderMask(
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
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
            AppLocalizations.of(context)!.createAccount,
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}
