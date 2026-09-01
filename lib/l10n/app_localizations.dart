import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @manageProfile.
  ///
  /// In en, this message translates to:
  /// **'Manage Profile'**
  String get manageProfile;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get off;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @bookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get bookings;

  /// No description provided for @newBooking.
  ///
  /// In en, this message translates to:
  /// **'New Booking'**
  String get newBooking;

  /// No description provided for @recentBookings.
  ///
  /// In en, this message translates to:
  /// **'Recent Bookings'**
  String get recentBookings;

  /// No description provided for @bookingInfo.
  ///
  /// In en, this message translates to:
  /// **'Booking Info'**
  String get bookingInfo;

  /// No description provided for @bookingTimeline.
  ///
  /// In en, this message translates to:
  /// **'Booking Timeline'**
  String get bookingTimeline;

  /// No description provided for @extraCharges.
  ///
  /// In en, this message translates to:
  /// **'Extra Charges'**
  String get extraCharges;

  /// No description provided for @bookingCategory.
  ///
  /// In en, this message translates to:
  /// **'Booking Category'**
  String get bookingCategory;

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brand;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @pricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricing;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// No description provided for @premiumFleet.
  ///
  /// In en, this message translates to:
  /// **'Premium Fleet'**
  String get premiumFleet;

  /// No description provided for @bookServices.
  ///
  /// In en, this message translates to:
  /// **'Book Services'**
  String get bookServices;

  /// No description provided for @airportArrival.
  ///
  /// In en, this message translates to:
  /// **'Airport Arrival'**
  String get airportArrival;

  /// No description provided for @airportDeparture.
  ///
  /// In en, this message translates to:
  /// **'Airport Departure'**
  String get airportDeparture;

  /// No description provided for @airportServices.
  ///
  /// In en, this message translates to:
  /// **'Airport Services'**
  String get airportServices;

  /// No description provided for @privateTransfer.
  ///
  /// In en, this message translates to:
  /// **'Private Transfer'**
  String get privateTransfer;

  /// No description provided for @useAirportServicesWarning.
  ///
  /// In en, this message translates to:
  /// **'For airport-related bookings, please use the Airport Services section.'**
  String get useAirportServicesWarning;

  /// No description provided for @goToBooking.
  ///
  /// In en, this message translates to:
  /// **'Go to booking'**
  String get goToBooking;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// No description provided for @chauffeurService.
  ///
  /// In en, this message translates to:
  /// **'Hourly Chauffeur'**
  String get chauffeurService;

  /// No description provided for @serviceDuration.
  ///
  /// In en, this message translates to:
  /// **'Service Duration'**
  String get serviceDuration;

  /// No description provided for @baseChauffeurChargeHourly.
  ///
  /// In en, this message translates to:
  /// **'Base Chauffeur Charge (Hourly)'**
  String get baseChauffeurChargeHourly;

  /// No description provided for @baseChauffeurCharge8Hours.
  ///
  /// In en, this message translates to:
  /// **'Base Chauffeur Charge (8 Hours)'**
  String get baseChauffeurCharge8Hours;

  /// No description provided for @baseChauffeurCharge12Hours.
  ///
  /// In en, this message translates to:
  /// **'Base Chauffeur Charge (12 Hours)'**
  String get baseChauffeurCharge12Hours;

  /// No description provided for @luxury.
  ///
  /// In en, this message translates to:
  /// **'Luxury'**
  String get luxury;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @airport.
  ///
  /// In en, this message translates to:
  /// **'Airport'**
  String get airport;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @noTerminals.
  ///
  /// In en, this message translates to:
  /// **'No terminals available'**
  String get noTerminals;

  /// No description provided for @riyadh.
  ///
  /// In en, this message translates to:
  /// **'Riyadh'**
  String get riyadh;

  /// No description provided for @jeddah.
  ///
  /// In en, this message translates to:
  /// **'Jeddah'**
  String get jeddah;

  /// No description provided for @dammam.
  ///
  /// In en, this message translates to:
  /// **'Dammam'**
  String get dammam;

  /// No description provided for @business.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get business;

  /// No description provided for @sedan.
  ///
  /// In en, this message translates to:
  /// **'Sedan'**
  String get sedan;

  /// No description provided for @suv.
  ///
  /// In en, this message translates to:
  /// **'SUV'**
  String get suv;

  /// No description provided for @yourJourneyIsSecuredWeLlNotifyYouOnceYourChauffeurIsAssigned.
  ///
  /// In en, this message translates to:
  /// **'Your journey is secured. We will notify you once your chauffeur is assigned.'**
  String get yourJourneyIsSecuredWeLlNotifyYouOnceYourChauffeurIsAssigned;

  /// No description provided for @convertible.
  ///
  /// In en, this message translates to:
  /// **'Convertible'**
  String get convertible;

  /// No description provided for @coupe.
  ///
  /// In en, this message translates to:
  /// **'Coupe'**
  String get coupe;

  /// No description provided for @sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get sports;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @economy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get economy;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @luxuryAirportTransfers.
  ///
  /// In en, this message translates to:
  /// **'Luxury Airport Transfers'**
  String get luxuryAirportTransfers;

  /// No description provided for @inSaudiArabia.
  ///
  /// In en, this message translates to:
  /// **'In Saudi Arabia'**
  String get inSaudiArabia;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @passenger.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get passenger;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @dropoff.
  ///
  /// In en, this message translates to:
  /// **'Dropoff'**
  String get dropoff;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @ongoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get ongoing;

  /// No description provided for @trackingStopped.
  ///
  /// In en, this message translates to:
  /// **'Tracking Stopped'**
  String get trackingStopped;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment Pending'**
  String get paymentPending;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @chooseCity.
  ///
  /// In en, this message translates to:
  /// **'Choose City'**
  String get chooseCity;

  /// No description provided for @chooseProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Choose Profile Picture'**
  String get chooseProfilePicture;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @promoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo Code'**
  String get promoCode;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @pleaseEnterYourPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter your promo code'**
  String get pleaseEnterYourPromoCode;

  /// No description provided for @enterYourPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your promo code'**
  String get enterYourPromoCode;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @tapToSelectYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to select your location'**
  String get tapToSelectYourLocation;

  /// No description provided for @pleaseEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterYourName;

  /// No description provided for @pleaseAddAProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Please add a profile picture'**
  String get pleaseAddAProfilePicture;

  /// No description provided for @pleaseSelectYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select your location'**
  String get pleaseSelectYourLocation;

  /// Error when airport booking location is outside the selected city.
  ///
  /// In en, this message translates to:
  /// **'Please choose a location within {city} city.'**
  String pleaseChooseLocationWithinCity(Object city);

  /// No description provided for @completeYourProfileToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile To Get Started'**
  String get completeYourProfileToGetStarted;

  /// No description provided for @tapToAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to add photo'**
  String get tapToAddPhoto;

  /// No description provided for @tapToAddPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Tap to add photo (Optional)'**
  String get tapToAddPhotoOptional;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @enterYourFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterYourFullName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @enterYourEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get enterYourEmailAddress;

  /// No description provided for @pleaseEnterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterYourEmail;

  /// No description provided for @nameMustBeAtLeast2Characters.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameMustBeAtLeast2Characters;

  /// No description provided for @pleaseEnterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterAValidEmail;

  /// No description provided for @specialidoptional.
  ///
  /// In en, this message translates to:
  /// **'Special ID (Optional)'**
  String get specialidoptional;

  /// No description provided for @enterSpecialIdIFAvailable.
  ///
  /// In en, this message translates to:
  /// **'Enter Special ID if available'**
  String get enterSpecialIdIFAvailable;

  /// No description provided for @enterYourSpecialId.
  ///
  /// In en, this message translates to:
  /// **'Enter your special ID'**
  String get enterYourSpecialId;

  /// No description provided for @pleaseEnterYourSpecialId.
  ///
  /// In en, this message translates to:
  /// **'Please enter your special ID'**
  String get pleaseEnterYourSpecialId;

  /// No description provided for @iAmACorporateEmployee.
  ///
  /// In en, this message translates to:
  /// **'Proceed if you are affiliated with a Premium Force partner company'**
  String get iAmACorporateEmployee;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @enterMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter mobile number'**
  String get enterMobileNumber;

  /// No description provided for @pleaseEnterYourMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your mobile number'**
  String get pleaseEnterYourMobileNumber;

  /// No description provided for @pleaseEnterValidMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid mobile number'**
  String get pleaseEnterValidMobileNumber;

  /// No description provided for @byContinuingYouAgreeToOur.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our'**
  String get byContinuingYouAgreeToOur;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// No description provided for @pleaseAgreeToTheTermsAndConditionsAndPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the terms and conditions and privacy policy.'**
  String get pleaseAgreeToTheTermsAndConditionsAndPrivacyPolicy;

  /// No description provided for @licenseNumber.
  ///
  /// In en, this message translates to:
  /// **'License Number'**
  String get licenseNumber;

  /// No description provided for @tripInfo.
  ///
  /// In en, this message translates to:
  /// **'Trip Info'**
  String get tripInfo;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// No description provided for @tracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get tracking;

  /// No description provided for @reviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewed;

  /// No description provided for @serviceType.
  ///
  /// In en, this message translates to:
  /// **'Service Type'**
  String get serviceType;

  /// No description provided for @tellUsAboutYourJourney.
  ///
  /// In en, this message translates to:
  /// **'Tell Us About Your Journey'**
  String get tellUsAboutYourJourney;

  /// No description provided for @enterFlightNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter Flight Number'**
  String get enterFlightNumber;

  /// No description provided for @flightNumber.
  ///
  /// In en, this message translates to:
  /// **'Flight Number (Optional)'**
  String get flightNumber;

  /// No description provided for @flightNumberMandatory.
  ///
  /// In en, this message translates to:
  /// **'Flight Number'**
  String get flightNumberMandatory;

  /// No description provided for @arrivalDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup Date and Time'**
  String get arrivalDateAndTime;

  /// No description provided for @departureDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup Date and Time'**
  String get departureDateAndTime;

  /// No description provided for @pickupDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup Date and Time'**
  String get pickupDateAndTime;

  /// No description provided for @pickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup Location'**
  String get pickupLocation;

  /// No description provided for @dropLocation.
  ///
  /// In en, this message translates to:
  /// **'Drop Off Location'**
  String get dropLocation;

  /// No description provided for @tapToSelectAPickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a pickup location'**
  String get tapToSelectAPickupLocation;

  /// No description provided for @tapToSelectADropLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a drop off location'**
  String get tapToSelectADropLocation;

  /// No description provided for @terminal1.
  ///
  /// In en, this message translates to:
  /// **'Terminal 1'**
  String get terminal1;

  /// No description provided for @terminal2.
  ///
  /// In en, this message translates to:
  /// **'Terminal 2'**
  String get terminal2;

  /// No description provided for @terminal3.
  ///
  /// In en, this message translates to:
  /// **'Terminal 3'**
  String get terminal3;

  /// No description provided for @terminal4.
  ///
  /// In en, this message translates to:
  /// **'Terminal 4'**
  String get terminal4;

  /// No description provided for @terminal5.
  ///
  /// In en, this message translates to:
  /// **'Terminal 5'**
  String get terminal5;

  /// No description provided for @hajjTerminal.
  ///
  /// In en, this message translates to:
  /// **'Hajj Terminal'**
  String get hajjTerminal;

  /// No description provided for @northTerminal.
  ///
  /// In en, this message translates to:
  /// **'North Terminal'**
  String get northTerminal;

  /// No description provided for @southTerminal.
  ///
  /// In en, this message translates to:
  /// **'South Terminal'**
  String get southTerminal;

  /// No description provided for @passengerTerminal.
  ///
  /// In en, this message translates to:
  /// **'Passenger Terminal'**
  String get passengerTerminal;

  /// No description provided for @aramcoTerminal.
  ///
  /// In en, this message translates to:
  /// **'Aramco Terminal'**
  String get aramcoTerminal;

  /// No description provided for @royalTerminal.
  ///
  /// In en, this message translates to:
  /// **'Royal Terminal'**
  String get royalTerminal;

  /// No description provided for @flightNumberIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Flight number is required'**
  String get flightNumberIsRequired;

  /// No description provided for @pickupLocationIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Pickup location is required'**
  String get pickupLocationIsRequired;

  /// No description provided for @dropLocationIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Drop off location is required'**
  String get dropLocationIsRequired;

  /// No description provided for @kingKhalidInternationalAirport.
  ///
  /// In en, this message translates to:
  /// **'King Khalid International Airport'**
  String get kingKhalidInternationalAirport;

  /// No description provided for @kingFahadInternationalAirport.
  ///
  /// In en, this message translates to:
  /// **'King Fahad International Airport'**
  String get kingFahadInternationalAirport;

  /// No description provided for @kingAbdulazizInternationalAirport.
  ///
  /// In en, this message translates to:
  /// **'King Abdulaziz International Airport'**
  String get kingAbdulazizInternationalAirport;

  /// No description provided for @pickupDateAndTimeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Pickup date and time are required'**
  String get pickupDateAndTimeIsRequired;

  /// No description provided for @dateAndTimeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Date and time are required'**
  String get dateAndTimeIsRequired;

  /// No description provided for @previouslySelectedTimeClearedAsItIsInThePast.
  ///
  /// In en, this message translates to:
  /// **'Previously selected time cleared as it is in the past'**
  String get previouslySelectedTimeClearedAsItIsInThePast;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @pleaseSelectADateFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a date first'**
  String get pleaseSelectADateFirst;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get selectTime;

  /// No description provided for @cannotSelectPastTimeForToday.
  ///
  /// In en, this message translates to:
  /// **'Cannot select past time for today'**
  String get cannotSelectPastTimeForToday;

  /// No description provided for @chooseYouPreferredVehicle.
  ///
  /// In en, this message translates to:
  /// **'Choose you preferred vehicle'**
  String get chooseYouPreferredVehicle;

  /// No description provided for @chauffeurredClass.
  ///
  /// In en, this message translates to:
  /// **'Chauffeurred Class'**
  String get chauffeurredClass;

  /// No description provided for @preferredModel.
  ///
  /// In en, this message translates to:
  /// **'Preferred Model'**
  String get preferredModel;

  /// No description provided for @choosePreferredBrand.
  ///
  /// In en, this message translates to:
  /// **'Choose Preferred Brand'**
  String get choosePreferredBrand;

  /// No description provided for @specialRequests.
  ///
  /// In en, this message translates to:
  /// **'Special Requests'**
  String get specialRequests;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @luxurySedan.
  ///
  /// In en, this message translates to:
  /// **'Luxury Sedan'**
  String get luxurySedan;

  /// No description provided for @luxurySuv.
  ///
  /// In en, this message translates to:
  /// **'Luxury SUV'**
  String get luxurySuv;

  /// No description provided for @luxuryCoupe.
  ///
  /// In en, this message translates to:
  /// **'Luxury Coupe'**
  String get luxuryCoupe;

  /// No description provided for @luxurySports.
  ///
  /// In en, this message translates to:
  /// **'Luxury Sports'**
  String get luxurySports;

  /// No description provided for @luxuryConvertible.
  ///
  /// In en, this message translates to:
  /// **'Luxury Convertible'**
  String get luxuryConvertible;

  /// No description provided for @model1.
  ///
  /// In en, this message translates to:
  /// **'Model 1'**
  String get model1;

  /// No description provided for @model2.
  ///
  /// In en, this message translates to:
  /// **'Model 2'**
  String get model2;

  /// No description provided for @model3.
  ///
  /// In en, this message translates to:
  /// **'Model 3'**
  String get model3;

  /// No description provided for @providePassengerInfo.
  ///
  /// In en, this message translates to:
  /// **'Provide Passenger Info'**
  String get providePassengerInfo;

  /// No description provided for @numberOfPassengers.
  ///
  /// In en, this message translates to:
  /// **'No. of Passengers'**
  String get numberOfPassengers;

  /// No description provided for @passengerNameAtleastOne.
  ///
  /// In en, this message translates to:
  /// **'Passenger Name (Atleast one separated by commas)'**
  String get passengerNameAtleastOne;

  /// No description provided for @passengerName.
  ///
  /// In en, this message translates to:
  /// **'Passenger Name'**
  String get passengerName;

  /// No description provided for @pleaseEnterAtleastOnepassengerName.
  ///
  /// In en, this message translates to:
  /// **'Please enter atleast one passenger name'**
  String get pleaseEnterAtleastOnepassengerName;

  /// No description provided for @pleaseEnterAMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a mobile number'**
  String get pleaseEnterAMobileNumber;

  /// No description provided for @pleaseEnterAPassengerName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a passenger name'**
  String get pleaseEnterAPassengerName;

  /// No description provided for @reviewAndConfirm.
  ///
  /// In en, this message translates to:
  /// **'Review and Confirm'**
  String get reviewAndConfirm;

  /// No description provided for @reviewAndConfirmYourRequest.
  ///
  /// In en, this message translates to:
  /// **'Review and Confirm Your Request'**
  String get reviewAndConfirmYourRequest;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @passengers.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get passengers;

  /// No description provided for @notAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not Assigned'**
  String get notAssigned;

  /// No description provided for @chauffeur.
  ///
  /// In en, this message translates to:
  /// **'Chauffeur'**
  String get chauffeur;

  /// No description provided for @totalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get totalDistance;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @vat.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get vat;

  /// No description provided for @paymentSummary.
  ///
  /// In en, this message translates to:
  /// **'Payment Summary'**
  String get paymentSummary;

  /// No description provided for @km.
  ///
  /// In en, this message translates to:
  /// **'KM'**
  String get km;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @charge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get charge;

  /// No description provided for @allowSimilarVehicle.
  ///
  /// In en, this message translates to:
  /// **'Allow Similar Vehicle'**
  String get allowSimilarVehicle;

  /// No description provided for @noCarsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No cars available'**
  String get noCarsAvailable;

  /// No description provided for @bookService.
  ///
  /// In en, this message translates to:
  /// **'Book Service'**
  String get bookService;

  /// No description provided for @companyEmail.
  ///
  /// In en, this message translates to:
  /// **'Company Email'**
  String get companyEmail;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @loginAgainMessage.
  ///
  /// In en, this message translates to:
  /// **'You will have to login again next time you open the app.'**
  String get loginAgainMessage;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone and all your data will be cleared.'**
  String get deleteAccountMessage;

  /// No description provided for @pickupTimeCannotBeAfterDepartureTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup time cannot be after departure time'**
  String get pickupTimeCannotBeAfterDepartureTime;

  /// No description provided for @pickupTimeAtLeast4HoursBeforeDeparture.
  ///
  /// In en, this message translates to:
  /// **'Pickup time must be at least 4 hours before departure time'**
  String get pickupTimeAtLeast4HoursBeforeDeparture;

  /// No description provided for @noRecentBookings.
  ///
  /// In en, this message translates to:
  /// **'No recent bookings'**
  String get noRecentBookings;

  /// No description provided for @noUpcomingBookings.
  ///
  /// In en, this message translates to:
  /// **'No upcoming bookings'**
  String get noUpcomingBookings;

  /// No description provided for @noOngoingBookings.
  ///
  /// In en, this message translates to:
  /// **'No ongoing bookings'**
  String get noOngoingBookings;

  /// No description provided for @noCompletedBookings.
  ///
  /// In en, this message translates to:
  /// **'No completed bookings'**
  String get noCompletedBookings;

  /// No description provided for @noCancelledBookings.
  ///
  /// In en, this message translates to:
  /// **'No cancelled bookings'**
  String get noCancelledBookings;

  /// No description provided for @onceYouBookItWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Once you book a service, it will appear here.'**
  String get onceYouBookItWillAppearHere;

  /// No description provided for @termsIntro.
  ///
  /// In en, this message translates to:
  /// **'These terms and conditions outline the rules and regulations for the use of the Premium Force application, a luxury chauffeur booking service operating in the Kingdom of Saudi Arabia.\n\nBy accessing this app, we assume you accept these terms and conditions. Do not continue to use Premium Force if you do not agree to take all of the terms and conditions stated on this page.\n'**
  String get termsIntro;

  /// No description provided for @termsSection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. App Services & Bookings'**
  String get termsSection1Title;

  /// No description provided for @termsSection1Content.
  ///
  /// In en, this message translates to:
  /// **'Premium Force connects users with luxury chauffeur services within Saudi Arabia. All bookings are subject to availability, and we reserve the right to decline or cancel bookings under specific circumstances outlined in our policies.'**
  String get termsSection1Content;

  /// No description provided for @termsSection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. User Responsibilities'**
  String get termsSection2Title;

  /// No description provided for @termsSection2Content.
  ///
  /// In en, this message translates to:
  /// **'You are specifically restricted from all of the following:\n• using this app in any way that impacts user access or disrupts the chauffeur services;\n• using this app contrary to the applicable laws and regulations of the Kingdom of Saudi Arabia;\n• behaving inappropriately towards our chauffeurs or damaging the provided luxury vehicles.'**
  String get termsSection2Content;

  /// No description provided for @termsSection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Payments & Cancellations'**
  String get termsSection3Title;

  /// No description provided for @termsSection3Content.
  ///
  /// In en, this message translates to:
  /// **'All payments for chauffeur services must be made through the approved methods within the app. Cancellation policies apply to all bookings. Late cancellations or no-shows may incur charges as detailed during the booking process.'**
  String get termsSection3Content;

  /// No description provided for @termsSection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Privacy'**
  String get termsSection4Title;

  /// No description provided for @termsSection4Content.
  ///
  /// In en, this message translates to:
  /// **'Please read our Privacy Policy. Your use of the Application signifies your continuing consent to our Privacy Policy regarding the collection and use of your personal and location data necessary for the chauffeur service.'**
  String get termsSection4Content;

  /// No description provided for @termsSection5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Disclaimer of Warranties'**
  String get termsSection5Title;

  /// No description provided for @termsSection5Content.
  ///
  /// In en, this message translates to:
  /// **'This app is provided \"as is,\" and Premium Force expresses no representations or warranties related to the continuous availability of the app or specific chauffeurs.'**
  String get termsSection5Content;

  /// No description provided for @termsSection6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Governing Law & Jurisdiction'**
  String get termsSection6Title;

  /// No description provided for @termsSection6Content.
  ///
  /// In en, this message translates to:
  /// **'These Terms will be governed by and interpreted in accordance with the laws of the Kingdom of Saudi Arabia, and you submit to the exclusive jurisdiction of the courts located in Saudi Arabia for the resolution of any disputes.'**
  String get termsSection6Content;

  /// No description provided for @termsSection7Title.
  ///
  /// In en, this message translates to:
  /// **'7. Changes and Amendments'**
  String get termsSection7Title;

  /// No description provided for @termsSection7Content.
  ///
  /// In en, this message translates to:
  /// **'We reserve the right to modify these terms or policies relating to the app or services at any time. Continued use of the app after any such changes shall constitute your consent to such changes.'**
  String get termsSection7Content;

  /// No description provided for @bookingConfirmedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed successfully!'**
  String get bookingConfirmedSuccessfully;

  /// No description provided for @bookingFailed.
  ///
  /// In en, this message translates to:
  /// **'Booking failed. Please try again.'**
  String get bookingFailed;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking Confirmed'**
  String get bookingConfirmed;

  /// No description provided for @byClickingContinueButton.
  ///
  /// In en, this message translates to:
  /// **'By Clicking continue button you agree to our '**
  String get byClickingContinueButton;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @invalidPhoneNumberOrCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Please check entered phone number'**
  String get invalidPhoneNumberOrCountryCode;

  /// No description provided for @pleaseCheckEnteredPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please check entered phone number'**
  String get pleaseCheckEnteredPhoneNumber;

  /// No description provided for @pleaseEnterAValidOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid OTP'**
  String get pleaseEnterAValidOtp;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @otpHasBeenSentTo.
  ///
  /// In en, this message translates to:
  /// **'OTP has been sent to '**
  String get otpHasBeenSentTo;

  /// No description provided for @didntReceiveTheCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? '**
  String get didntReceiveTheCode;

  /// No description provided for @otpHasBeenResentTo.
  ///
  /// In en, this message translates to:
  /// **'OTP has been resent to '**
  String get otpHasBeenResentTo;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in '**
  String get resendIn;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitApp;

  /// No description provided for @exitAppConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to exit the app?'**
  String get exitAppConfirm;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @cannotReviewWithoutValidDriver.
  ///
  /// In en, this message translates to:
  /// **'Cannot review without a valid driver.'**
  String get cannotReviewWithoutValidDriver;

  /// No description provided for @reviewSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully.'**
  String get reviewSubmittedSuccessfully;

  /// No description provided for @paymentSuccessfulBookingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment successful. Booking completed!'**
  String get paymentSuccessfulBookingCompleted;

  /// No description provided for @paymentError.
  ///
  /// In en, this message translates to:
  /// **'Payment error: '**
  String get paymentError;

  /// No description provided for @policyLinkComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Policy link coming soon!'**
  String get policyLinkComingSoon;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @bookingCancelledSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled successfully'**
  String get bookingCancelledSuccessfully;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error: '**
  String get error;

  /// No description provided for @locationServicesAreDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled.'**
  String get locationServicesAreDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get locationPermissionDenied;

  /// No description provided for @errorGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Error getting location: '**
  String get errorGettingLocation;

  /// No description provided for @trackYourDriver.
  ///
  /// In en, this message translates to:
  /// **'Track Your Driver'**
  String get trackYourDriver;

  /// No description provided for @airportArrivalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Airport Arrival — Driver en route to you'**
  String get airportArrivalSubtitle;

  /// No description provided for @airportDepartureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Airport Departure — Driver coming to pick up'**
  String get airportDepartureSubtitle;

  /// No description provided for @chauffeurServiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chauffeur Service — Driver en route to pickup'**
  String get chauffeurServiceSubtitle;

  /// No description provided for @driverOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way'**
  String get driverOnTheWay;

  /// No description provided for @tripEnded.
  ///
  /// In en, this message translates to:
  /// **'Trip Ended'**
  String get tripEnded;

  /// No description provided for @waitingForDriver.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver...'**
  String get waitingForDriver;

  /// No description provided for @waitingForLocation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver location...'**
  String get waitingForLocation;

  /// No description provided for @etaPrefix.
  ///
  /// In en, this message translates to:
  /// **'ETA:'**
  String get etaPrefix;

  /// No description provided for @calculatingEta.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculatingEta;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String etaMinutes(int count);

  /// No description provided for @etaHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr {minutes} min'**
  String etaHoursMinutes(int hours, int minutes);

  /// No description provided for @etaApprox.
  ///
  /// In en, this message translates to:
  /// **'{eta} (approx)'**
  String etaApprox(String eta);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @liveLocationPaused.
  ///
  /// In en, this message translates to:
  /// **'Live location paused'**
  String get liveLocationPaused;

  /// No description provided for @recenterMap.
  ///
  /// In en, this message translates to:
  /// **'Recentre'**
  String get recenterMap;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @showFullRoute.
  ///
  /// In en, this message translates to:
  /// **'Show full route'**
  String get showFullRoute;

  /// No description provided for @pickupPointLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup Point'**
  String get pickupPointLabel;

  /// No description provided for @airportDropoffLabel.
  ///
  /// In en, this message translates to:
  /// **'Airport (Dropoff)'**
  String get airportDropoffLabel;

  /// No description provided for @airportPickupLabel.
  ///
  /// In en, this message translates to:
  /// **'Airport (Pickup)'**
  String get airportPickupLabel;

  /// No description provided for @dropoffPointLabel.
  ///
  /// In en, this message translates to:
  /// **'Dropoff Point'**
  String get dropoffPointLabel;

  /// No description provided for @driverMarkerTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverMarkerTitle;

  /// No description provided for @extraHoursCharge.
  ///
  /// In en, this message translates to:
  /// **'Extra Hours Charge'**
  String get extraHoursCharge;

  /// No description provided for @extraHours.
  ///
  /// In en, this message translates to:
  /// **'Extra Hours'**
  String get extraHours;

  /// No description provided for @totalExtraDue.
  ///
  /// In en, this message translates to:
  /// **'Total Extra Due'**
  String get totalExtraDue;

  /// No description provided for @completePayment.
  ///
  /// In en, this message translates to:
  /// **'Complete Payment'**
  String get completePayment;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get cancelBooking;

  /// No description provided for @cancelBookingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this booking?'**
  String get cancelBookingConfirm;

  /// No description provided for @viewCancellationPolicy.
  ///
  /// In en, this message translates to:
  /// **'View Cancellation & Privacy Policy'**
  String get viewCancellationPolicy;

  /// No description provided for @yesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, Cancel'**
  String get yesCancel;

  /// No description provided for @tripCompletedStatus.
  ///
  /// In en, this message translates to:
  /// **'Trip Completed'**
  String get tripCompletedStatus;

  /// No description provided for @bookingCanceledStatus.
  ///
  /// In en, this message translates to:
  /// **'This booking has been canceled'**
  String get bookingCanceledStatus;

  /// No description provided for @pendingDriverStatus.
  ///
  /// In en, this message translates to:
  /// **'A driver will be assigned to you soon!'**
  String get pendingDriverStatus;

  /// No description provided for @driverAssignedStatus.
  ///
  /// In en, this message translates to:
  /// **'A driver has been assigned!'**
  String get driverAssignedStatus;

  /// No description provided for @rideInProgressStatus.
  ///
  /// In en, this message translates to:
  /// **'Your ride is in progress.'**
  String get rideInProgressStatus;

  /// No description provided for @rideCompletedStatus.
  ///
  /// In en, this message translates to:
  /// **'Your ride is complete. Thank you for riding with us!'**
  String get rideCompletedStatus;

  /// No description provided for @paymentPendingStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment pending for extra hours.'**
  String get paymentPendingStatus;

  /// No description provided for @tripReviewedStatus.
  ///
  /// In en, this message translates to:
  /// **'Trip reviewed.'**
  String get tripReviewedStatus;

  /// No description provided for @extraHoursInfo.
  ///
  /// In en, this message translates to:
  /// **'Any additional hours beyond the selected duration will be charged accordingly. Payment for these extra hours will be settled at the completion of your journey.'**
  String get extraHoursInfo;

  /// No description provided for @paymentOkFailedUpdate.
  ///
  /// In en, this message translates to:
  /// **'Payment ok, but failed to update booking.'**
  String get paymentOkFailedUpdate;

  /// No description provided for @pleaseAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the terms and conditions and privacy policy.'**
  String get pleaseAgreeToTerms;

  /// No description provided for @trackDriver.
  ///
  /// In en, this message translates to:
  /// **'Track Driver'**
  String get trackDriver;

  /// No description provided for @cancelBookingButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get cancelBookingButton;

  /// No description provided for @yourReview.
  ///
  /// In en, this message translates to:
  /// **'Your Review'**
  String get yourReview;

  /// No description provided for @leaveAReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a Review'**
  String get leaveAReview;

  /// No description provided for @rateYourDriver.
  ///
  /// In en, this message translates to:
  /// **'Rate your Driver'**
  String get rateYourDriver;

  /// No description provided for @addAnOptionalReview.
  ///
  /// In en, this message translates to:
  /// **'Add an optional review...'**
  String get addAnOptionalReview;

  /// No description provided for @transactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetails;

  /// No description provided for @orderIDLabel.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get orderIDLabel;

  /// No description provided for @transactionIDLabel.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionIDLabel;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copiedToClipboard(Object label);

  /// No description provided for @driverAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver Assigned'**
  String get driverAssigned;

  /// No description provided for @id.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get id;

  /// No description provided for @riyal.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get riyal;

  /// No description provided for @hrs.
  ///
  /// In en, this message translates to:
  /// **'hrs'**
  String get hrs;

  /// No description provided for @extraHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Extra Hours'**
  String get extraHoursLabel;

  /// No description provided for @errorLaunchingDialer.
  ///
  /// In en, this message translates to:
  /// **'Error launching dialer: '**
  String get errorLaunchingDialer;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @pickupTimeAtLeast1HourFromNow.
  ///
  /// In en, this message translates to:
  /// **'Pickup time must be at least 1 hour from now.'**
  String get pickupTimeAtLeast1HourFromNow;

  /// No description provided for @voiceNoteSaved.
  ///
  /// In en, this message translates to:
  /// **'Voice note successfully saved.'**
  String get voiceNoteSaved;

  /// No description provided for @noBrandsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No brands available'**
  String get noBrandsAvailable;

  /// No description provided for @hourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get hourly;

  /// No description provided for @eightHours.
  ///
  /// In en, this message translates to:
  /// **'8 Hours'**
  String get eightHours;

  /// No description provided for @twelveHours.
  ///
  /// In en, this message translates to:
  /// **'12 Hours'**
  String get twelveHours;

  /// No description provided for @estimatedHours.
  ///
  /// In en, this message translates to:
  /// **'Estimated hours'**
  String get estimatedHours;

  /// No description provided for @rideBookingFor.
  ///
  /// In en, this message translates to:
  /// **'Ride Booking for {vehicleClass}'**
  String rideBookingFor(Object vehicleClass);

  /// No description provided for @serviceNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Service Not Available'**
  String get serviceNotAvailable;

  /// No description provided for @serviceNotAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Service not available for this route or vehicle. Please contact support or try another selection.'**
  String get serviceNotAvailableMessage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @promoCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Promo code expired, please add a new promo code'**
  String get promoCodeExpired;

  /// No description provided for @promoCodeAppliedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Promo code applied successfully!'**
  String get promoCodeAppliedSuccessfully;

  /// No description provided for @promoCodeIsInactive.
  ///
  /// In en, this message translates to:
  /// **'Promo code is inactive'**
  String get promoCodeIsInactive;

  /// No description provided for @invalidPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid promo code'**
  String get invalidPromoCode;

  /// No description provided for @invalidOrInactivePromoCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or inactive promo code'**
  String get invalidOrInactivePromoCode;

  /// No description provided for @promoCodeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Promo code removed'**
  String get promoCodeRemoved;

  /// No description provided for @signupFailed.
  ///
  /// In en, this message translates to:
  /// **'Signup failed'**
  String get signupFailed;

  /// No description provided for @locationPermissionsPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied. Enable from settings.'**
  String get locationPermissionsPermanentlyDenied;

  /// No description provided for @searchForALocation.
  ///
  /// In en, this message translates to:
  /// **'Search for a location...'**
  String get searchForALocation;

  /// No description provided for @selectedLocationDisplay.
  ///
  /// In en, this message translates to:
  /// **'Selected Location'**
  String get selectedLocationDisplay;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting location...'**
  String get gettingLocation;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get useCurrentLocation;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get confirmLocation;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @voiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice Note'**
  String get voiceNote;

  /// No description provided for @recordVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Record voice note'**
  String get recordVoiceNote;

  /// No description provided for @saveVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Save Voice Note'**
  String get saveVoiceNote;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @accountBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Blocked'**
  String get accountBlockedTitle;

  /// No description provided for @accountBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deactivated. Please contact support for assistance.'**
  String get accountBlockedMessage;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @similarVehicleNote.
  ///
  /// In en, this message translates to:
  /// **'If your selected vehicle is unavailable, we will provide a comparable alternative that meets all your specifications.'**
  String get similarVehicleNote;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @selectContactMethod.
  ///
  /// In en, this message translates to:
  /// **'Select contact method'**
  String get selectContactMethod;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No Notifications Yet'**
  String get noNotificationsYet;

  /// No description provided for @updatesAboutBookings.
  ///
  /// In en, this message translates to:
  /// **'Updates about your bookings will appear here.'**
  String get updatesAboutBookings;

  /// No description provided for @clearAllConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all notifications?'**
  String get clearAllConfirmDesc;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Support Email: {email}'**
  String supportEmail(Object email);

  /// No description provided for @vehicleNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Vehicle not selected'**
  String get vehicleNotSelected;

  /// No description provided for @noPricingAvailableForSelectedDuration.
  ///
  /// In en, this message translates to:
  /// **'No pricing available for the selected duration'**
  String get noPricingAvailableForSelectedDuration;

  /// No description provided for @unableToFetchPricingForThisVehicle.
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch pricing for this vehicle.'**
  String get unableToFetchPricingForThisVehicle;

  /// No description provided for @incompleteLocationData.
  ///
  /// In en, this message translates to:
  /// **'Incomplete location data.'**
  String get incompleteLocationData;

  /// No description provided for @serviceNotAvailableToSelectedArea.
  ///
  /// In en, this message translates to:
  /// **'Service not available to the selected area.'**
  String get serviceNotAvailableToSelectedArea;

  /// No description provided for @noPriceSetForThisVehicleOnThisRoute.
  ///
  /// In en, this message translates to:
  /// **'No price set for this vehicle on this route.'**
  String get noPriceSetForThisVehicleOnThisRoute;

  /// No description provided for @noVehiclesAvailableForThisRoute.
  ///
  /// In en, this message translates to:
  /// **'No vehicles available for this route.'**
  String get noVehiclesAvailableForThisRoute;

  /// No description provided for @selectedRouteNotAvailableForThisVehicle.
  ///
  /// In en, this message translates to:
  /// **'Selected route is not available for this vehicle.'**
  String get selectedRouteNotAvailableForThisVehicle;

  /// No description provided for @routeNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Route not available.'**
  String get routeNotAvailable;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get selectPaymentMethod;

  /// No description provided for @applePay.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get applePay;

  /// No description provided for @creditDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Credit/Debit Card'**
  String get creditDebitCard;

  /// No description provided for @selectDuration.
  ///
  /// In en, this message translates to:
  /// **'Select Duration'**
  String get selectDuration;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get refunded;

  /// No description provided for @refundProcessed.
  ///
  /// In en, this message translates to:
  /// **'Refund Processed'**
  String get refundProcessed;

  /// No description provided for @refundReference.
  ///
  /// In en, this message translates to:
  /// **'Refund Ref'**
  String get refundReference;

  /// No description provided for @refundBusinessDaysNote.
  ///
  /// In en, this message translates to:
  /// **'Funds will appear on your card statement within 3 to 5 business days, depending on your issuing bank.'**
  String get refundBusinessDaysNote;

  /// No description provided for @noAirportsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No airports available'**
  String get noAirportsAvailable;

  /// No description provided for @enterYourCompanyEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your company email'**
  String get enterYourCompanyEmail;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification Pending'**
  String get verificationPending;

  /// No description provided for @discountApproved.
  ///
  /// In en, this message translates to:
  /// **'Discount Approved'**
  String get discountApproved;

  /// No description provided for @discountRejected.
  ///
  /// In en, this message translates to:
  /// **'Discount Rejected'**
  String get discountRejected;

  /// No description provided for @nHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Hour} other{{count} Hours}}'**
  String nHours(int count);

  /// No description provided for @viewInvoice.
  ///
  /// In en, this message translates to:
  /// **'View Invoice'**
  String get viewInvoice;

  /// No description provided for @preparingInvoice.
  ///
  /// In en, this message translates to:
  /// **'Preparing your invoice...'**
  String get preparingInvoice;

  /// No description provided for @invoiceNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'The invoice will be available once your payment is confirmed.'**
  String get invoiceNotAvailableYet;

  /// No description provided for @noPdfViewerFound.
  ///
  /// In en, this message translates to:
  /// **'No PDF viewer was found on this device. The invoice has been saved to your files.'**
  String get noPdfViewerFound;

  /// No description provided for @couldNotOpenInvoice.
  ///
  /// In en, this message translates to:
  /// **'Could not open the invoice. Please try again.'**
  String get couldNotOpenInvoice;

  /// No description provided for @pleaseSelectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select a rating first.'**
  String get pleaseSelectRating;

  /// No description provided for @markAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllAsRead;

  /// No description provided for @allNotificationsMarkedRead.
  ///
  /// In en, this message translates to:
  /// **'All notifications marked as read'**
  String get allNotificationsMarkedRead;

  /// No description provided for @notificationsCleared.
  ///
  /// In en, this message translates to:
  /// **'All notifications cleared'**
  String get notificationsCleared;

  /// No description provided for @cancellationNote.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Note'**
  String get cancellationNote;

  /// No description provided for @cancellationReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for cancellation'**
  String get cancellationReason;

  /// No description provided for @cancellationReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us why you are cancelling'**
  String get cancellationReasonHint;

  /// No description provided for @onTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the Way'**
  String get onTheWay;

  /// No description provided for @arrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get arrived;

  /// No description provided for @failedToDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again.'**
  String get failedToDeleteAccount;

  /// No description provided for @cannotMakePhoneCalls.
  ///
  /// In en, this message translates to:
  /// **'Cannot make phone calls on this device.'**
  String get cannotMakePhoneCalls;

  /// No description provided for @couldNotPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Could not play the voice note.'**
  String get couldNotPlayAudio;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @systemMode.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemMode;

  /// No description provided for @systemModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow your device\'s display setting'**
  String get systemModeDescription;

  /// No description provided for @mapStyle.
  ///
  /// In en, this message translates to:
  /// **'Map style'**
  String get mapStyle;

  /// No description provided for @mapStyleMatchApp.
  ///
  /// In en, this message translates to:
  /// **'Match app'**
  String get mapStyleMatchApp;

  /// No description provided for @mapStyleLight.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get mapStyleLight;

  /// No description provided for @mapStyleDark.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get mapStyleDark;

  /// No description provided for @mapStyleDescription.
  ///
  /// In en, this message translates to:
  /// **'Used on the driver tracking map'**
  String get mapStyleDescription;

  /// No description provided for @switchToLightMap.
  ///
  /// In en, this message translates to:
  /// **'Switch to the day map'**
  String get switchToLightMap;

  /// No description provided for @switchToDarkMap.
  ///
  /// In en, this message translates to:
  /// **'Switch to the night map'**
  String get switchToDarkMap;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment Cancelled'**
  String get paymentCancelled;

  /// No description provided for @paymentCancelledDescription.
  ///
  /// In en, this message translates to:
  /// **'The payment process was cancelled. No charges were made to your account.'**
  String get paymentCancelledDescription;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @paymentRejected.
  ///
  /// In en, this message translates to:
  /// **'Payment Rejected'**
  String get paymentRejected;

  /// No description provided for @paymentSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong with your payment. Please try again or use a different payment method.'**
  String get paymentSomethingWentWrong;

  /// No description provided for @paymentSecurityVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Security verification failed. Please ensure your card details are correct or try a different payment method.'**
  String get paymentSecurityVerificationFailed;

  /// No description provided for @paymentInsufficientFunds.
  ///
  /// In en, this message translates to:
  /// **'The transaction was declined due to insufficient funds. Please check your account or use another card.'**
  String get paymentInsufficientFunds;

  /// No description provided for @paymentCardDeclined.
  ///
  /// In en, this message translates to:
  /// **'Your card was declined by the issuer. Please contact your bank or use a different payment method.'**
  String get paymentCardDeclined;

  /// No description provided for @paymentCardExpired.
  ///
  /// In en, this message translates to:
  /// **'The card used has expired. Please provide a valid card and try again.'**
  String get paymentCardExpired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
