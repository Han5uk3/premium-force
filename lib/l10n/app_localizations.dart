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

  /// No description provided for @chauffeurService.
  ///
  /// In en, this message translates to:
  /// **'Chauffeur Service'**
  String get chauffeurService;

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

  /// No description provided for @specialId.
  ///
  /// In en, this message translates to:
  /// **'Special ID'**
  String get specialId;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

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
  /// **'Flight Number'**
  String get flightNumber;

  /// No description provided for @arrivalDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Arrival Date and Time'**
  String get arrivalDateAndTime;

  /// No description provided for @departureDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Departure Date and Time'**
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
  /// **'Drop Location'**
  String get dropLocation;

  /// No description provided for @tapToSelectAPickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a pickup location'**
  String get tapToSelectAPickupLocation;

  /// No description provided for @tapToSelectADropLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a drop location'**
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
  /// **'Drop location is required'**
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

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;
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
