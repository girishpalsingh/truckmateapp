import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pa.dart';

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
    Locale('en'),
    Locale('pa')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'TruckMate'**
  String get appName;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਜੀ ਆਇਆਂ ਨੂੰ'**
  String get welcomeSubtitle;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @getStartedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸ਼ੁਰੂ ਕਰੋ'**
  String get getStartedSubtitle;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @phoneNumberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਫ਼ੋਨ ਨੰਬਰ'**
  String get phoneNumberSubtitle;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhoneNumber;

  /// No description provided for @enterPhoneNumberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਆਪਣਾ ਫ਼ੋਨ ਨੰਬਰ ਦਾਖਲ ਕਰੋ'**
  String get enterPhoneNumberSubtitle;

  /// No description provided for @sendOTP.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOTP;

  /// No description provided for @sendOTPSubtitle.
  ///
  /// In en, this message translates to:
  /// **'OTP ਭੇਜੋ'**
  String get sendOTPSubtitle;

  /// No description provided for @enterOTP.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOTP;

  /// No description provided for @enterOTPSubtitle.
  ///
  /// In en, this message translates to:
  /// **'OTP ਦਾਖਲ ਕਰੋ'**
  String get enterOTPSubtitle;

  /// No description provided for @verifyOTP.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOTP;

  /// No description provided for @verifyOTPSubtitle.
  ///
  /// In en, this message translates to:
  /// **'OTP ਪੁਸ਼ਟੀ ਕਰੋ'**
  String get verifyOTPSubtitle;

  /// No description provided for @resendOTP.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOTP;

  /// No description provided for @resendOTPSubtitle.
  ///
  /// In en, this message translates to:
  /// **'OTP ਦੁਬਾਰਾ ਭੇਜੋ'**
  String get resendOTPSubtitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਲੌਗਇਨ'**
  String get loginSubtitle;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਲੌਗਆਉਟ'**
  String get logoutSubtitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਡੈਸ਼ਬੋਰਡ'**
  String get dashboardSubtitle;

  /// No description provided for @startTrip.
  ///
  /// In en, this message translates to:
  /// **'Start Trip'**
  String get startTrip;

  /// No description provided for @startTripSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਯਾਤਰਾ ਸ਼ੁਰੂ ਕਰੋ'**
  String get startTripSubtitle;

  /// No description provided for @endTrip.
  ///
  /// In en, this message translates to:
  /// **'End Trip'**
  String get endTrip;

  /// No description provided for @endTripSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਯਾਤਰਾ ਖ਼ਤਮ ਕਰੋ'**
  String get endTripSubtitle;

  /// No description provided for @activeTrip.
  ///
  /// In en, this message translates to:
  /// **'Active Trip'**
  String get activeTrip;

  /// No description provided for @activeTripSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸਰਗਰਮ ਯਾਤਰਾ'**
  String get activeTripSubtitle;

  /// No description provided for @noActiveTrip.
  ///
  /// In en, this message translates to:
  /// **'No Active Trip'**
  String get noActiveTrip;

  /// No description provided for @noActiveTripSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਕੋਈ ਸਰਗਰਮ ਯਾਤਰਾ ਨਹੀਂ'**
  String get noActiveTripSubtitle;

  /// No description provided for @scanDocument.
  ///
  /// In en, this message translates to:
  /// **'Scan Document'**
  String get scanDocument;

  /// No description provided for @scanDocumentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦਸਤਾਵੇਜ਼ ਸਕੈਨ ਕਰੋ'**
  String get scanDocumentSubtitle;

  /// No description provided for @uploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get uploadDocument;

  /// No description provided for @uploadDocumentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦਸਤਾਵੇਜ਼ ਅੱਪਲੋਡ ਕਰੋ'**
  String get uploadDocumentSubtitle;

  /// No description provided for @logFuel.
  ///
  /// In en, this message translates to:
  /// **'Log Fuel'**
  String get logFuel;

  /// No description provided for @logFuelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਈਂਧਣ ਲੌਗ ਕਰੋ'**
  String get logFuelSubtitle;

  /// No description provided for @logExpense.
  ///
  /// In en, this message translates to:
  /// **'Log Expense'**
  String get logExpense;

  /// No description provided for @logExpenseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਖਰਚਾ ਲੌਗ ਕਰੋ'**
  String get logExpenseSubtitle;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @expensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਖਰਚੇ'**
  String get expensesSubtitle;

  /// No description provided for @trips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get trips;

  /// No description provided for @tripsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਯਾਤਰਾਵਾਂ'**
  String get tripsSubtitle;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @documentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦਸਤਾਵੇਜ਼'**
  String get documentsSubtitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸੈਟਿੰਗਾਂ'**
  String get settingsSubtitle;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਪ੍ਰੋਫਾਈਲ'**
  String get profileSubtitle;

  /// No description provided for @origin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get origin;

  /// No description provided for @originSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਮੂਲ'**
  String get originSubtitle;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @destinationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਮੰਜ਼ਿਲ'**
  String get destinationSubtitle;

  /// No description provided for @odometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get odometer;

  /// No description provided for @odometerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਓਡੋਮੀਟਰ'**
  String get odometerSubtitle;

  /// No description provided for @miles.
  ///
  /// In en, this message translates to:
  /// **'Miles'**
  String get miles;

  /// No description provided for @milesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਮੀਲ'**
  String get milesSubtitle;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @amountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਰਕਮ'**
  String get amountSubtitle;

  /// No description provided for @gallons.
  ///
  /// In en, this message translates to:
  /// **'Gallons'**
  String get gallons;

  /// No description provided for @gallonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਗੈਲਨ'**
  String get gallonsSubtitle;

  /// No description provided for @vendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendor;

  /// No description provided for @vendorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਵਿਕਰੇਤਾ'**
  String get vendorSubtitle;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @dateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਤਾਰੀਖ਼'**
  String get dateSubtitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸੰਭਾਲੋ'**
  String get saveSubtitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cancelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਰੱਦ ਕਰੋ'**
  String get cancelSubtitle;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਪੁਸ਼ਟੀ ਕਰੋ'**
  String get confirmSubtitle;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਮਿਟਾਓ'**
  String get deleteSubtitle;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸੋਧੋ'**
  String get editSubtitle;

  /// No description provided for @fuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get fuel;

  /// No description provided for @fuelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਈਂਧਣ'**
  String get fuelSubtitle;

  /// No description provided for @tolls.
  ///
  /// In en, this message translates to:
  /// **'Tolls'**
  String get tolls;

  /// No description provided for @tollsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਟੋਲ'**
  String get tollsSubtitle;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @foodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਖਾਣਾ'**
  String get foodSubtitle;

  /// No description provided for @lodging.
  ///
  /// In en, this message translates to:
  /// **'Lodging'**
  String get lodging;

  /// No description provided for @lodgingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਰਿਹਾਇਸ਼'**
  String get lodgingSubtitle;

  /// No description provided for @repair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get repair;

  /// No description provided for @repairSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਮੁਰੰਮਤ'**
  String get repairSubtitle;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @otherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਹੋਰ'**
  String get otherSubtitle;

  /// No description provided for @rateCon.
  ///
  /// In en, this message translates to:
  /// **'Rate Confirmation'**
  String get rateCon;

  /// No description provided for @rateConSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦਰ ਪੁਸ਼ਟੀ'**
  String get rateConSubtitle;

  /// No description provided for @billOfLading.
  ///
  /// In en, this message translates to:
  /// **'Bill of Lading'**
  String get billOfLading;

  /// No description provided for @billOfLadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਲੈਡਿੰਗ ਬਿੱਲ'**
  String get billOfLadingSubtitle;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @receiptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਰਸੀਦ'**
  String get receiptSubtitle;

  /// No description provided for @netProfit.
  ///
  /// In en, this message translates to:
  /// **'Net Profit'**
  String get netProfit;

  /// No description provided for @netProfitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸਾਫ਼ ਲਾਭ'**
  String get netProfitSubtitle;

  /// No description provided for @totalMiles.
  ///
  /// In en, this message translates to:
  /// **'Total Miles'**
  String get totalMiles;

  /// No description provided for @totalMilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਕੁੱਲ ਮੀਲ'**
  String get totalMilesSubtitle;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingReview;

  /// No description provided for @pendingReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸਮੀਖਿਆ ਬਾਕੀ'**
  String get pendingReviewSubtitle;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @approvedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਮਨਜ਼ੂਰ'**
  String get approvedSubtitle;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @rejectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਰੱਦ'**
  String get rejectedSubtitle;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @offlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਆਫ਼ਲਾਈਨ'**
  String get offlineSubtitle;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncing;

  /// No description provided for @syncingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸਿੰਕ ਹੋ ਰਿਹਾ ਹੈ'**
  String get syncingSubtitle;

  /// No description provided for @voiceCommand.
  ///
  /// In en, this message translates to:
  /// **'Voice Command'**
  String get voiceCommand;

  /// No description provided for @voiceCommandSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਆਵਾਜ਼ ਕਮਾਂਡ'**
  String get voiceCommandSubtitle;

  /// No description provided for @speakNow.
  ///
  /// In en, this message translates to:
  /// **'Speak Now'**
  String get speakNow;

  /// No description provided for @speakNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਹੁਣ ਬੋਲੋ'**
  String get speakNowSubtitle;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @listeningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸੁਣ ਰਿਹਾ ਹਾਂ...'**
  String get listeningSubtitle;

  /// No description provided for @selectDocumentType.
  ///
  /// In en, this message translates to:
  /// **'Select Document Type'**
  String get selectDocumentType;

  /// No description provided for @selectDocumentTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦਸਤਾਵੇਜ਼ ਦੀ ਕਿਸਮ ਚੁਣੋ'**
  String get selectDocumentTypeSubtitle;

  /// No description provided for @takePicture.
  ///
  /// In en, this message translates to:
  /// **'Take Picture'**
  String get takePicture;

  /// No description provided for @takePictureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਤਸਵੀਰ ਲਓ'**
  String get takePictureSubtitle;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @retakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦੁਬਾਰਾ ਲਓ'**
  String get retakeSubtitle;

  /// No description provided for @usePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use Photo'**
  String get usePhoto;

  /// No description provided for @usePhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਫੋਟੋ ਵਰਤੋ'**
  String get usePhotoSubtitle;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @processingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਪ੍ਰੋਸੈਸ ਹੋ ਰਿਹਾ ਹੈ...'**
  String get processingSubtitle;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @errorOccurredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਇੱਕ ਗਲਤੀ ਹੋਈ'**
  String get errorOccurredSubtitle;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @tryAgainSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ'**
  String get tryAgainSubtitle;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @successSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਸਫਲਤਾ'**
  String get successSubtitle;

  /// No description provided for @invalidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get invalidPhoneNumber;

  /// No description provided for @invalidPhoneNumberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਗਲਤ ਫ਼ੋਨ ਨੰਬਰ'**
  String get invalidPhoneNumberSubtitle;

  /// No description provided for @invalidOTP.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP'**
  String get invalidOTP;

  /// No description provided for @invalidOTPSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਗਲਤ OTP'**
  String get invalidOTPSubtitle;

  /// No description provided for @logoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirmation;

  /// No description provided for @logoutConfirmationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਕੀ ਤੁਸੀਂ ਯਕੀਨਨ ਲੌਗ ਆਉਟ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?'**
  String get logoutConfirmationSubtitle;

  /// No description provided for @viewTripDetails.
  ///
  /// In en, this message translates to:
  /// **'View Trip Details'**
  String get viewTripDetails;

  /// No description provided for @viewTripDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਯਾਤਰਾ ਦੇ ਵੇਰਵੇ ਵੇਖੋ'**
  String get viewTripDetailsSubtitle;

  /// No description provided for @startNewTripTracking.
  ///
  /// In en, this message translates to:
  /// **'Start a new trip to begin tracking'**
  String get startNewTripTracking;

  /// No description provided for @startNewTripTrackingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਟ੍ਰੈਕਿੰਗ ਸ਼ੁਰੂ ਕਰਨ ਲਈ ਨਵੀਂ ਯਾਤਰਾ ਸ਼ੁਰੂ ਕਰੋ'**
  String get startNewTripTrackingSubtitle;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @quickActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਤੇਜ਼ ਕਾਰਵਾਈਆਂ'**
  String get quickActionsSubtitle;

  /// No description provided for @uploadRateCon.
  ///
  /// In en, this message translates to:
  /// **'Upload Rate Con'**
  String get uploadRateCon;

  /// No description provided for @uploadRateConSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਨਵਾਂ ਰੇਟ ਕੌਨ ਅੱਪਲੋਡ ਕਰੋ'**
  String get uploadRateConSubtitle;

  /// No description provided for @showOldLoads.
  ///
  /// In en, this message translates to:
  /// **'Show Old Loads'**
  String get showOldLoads;

  /// No description provided for @showOldLoadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਪੁਰਾਣੇ ਲੋਡ ਵੇਖੋ'**
  String get showOldLoadsSubtitle;

  /// No description provided for @searchDocuments.
  ///
  /// In en, this message translates to:
  /// **'Search Documents'**
  String get searchDocuments;

  /// No description provided for @searchDocumentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦਸਤਾਵੇਜ਼ ਖੋਜੋ'**
  String get searchDocumentsSubtitle;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @filesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਫਾਇਲਾਂ'**
  String get filesSubtitle;

  /// No description provided for @scanDoc.
  ///
  /// In en, this message translates to:
  /// **'Scan Doc'**
  String get scanDoc;

  /// No description provided for @scanDocSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦਸਤਾਵੇਜ਼ ਸਕੈਨ'**
  String get scanDocSubtitle;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpense;

  /// No description provided for @addExpenseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਖਰਚਾ ਜੋੜੋ'**
  String get addExpenseSubtitle;

  /// No description provided for @voiceCommandsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Voice commands coming soon!'**
  String get voiceCommandsComingSoon;

  /// No description provided for @voiceCommandsComingSoonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਆਵਾਜ਼ ਕਮਾਂਡ ਜਲਦੀ ਆ ਰਹੇ ਹਨ!'**
  String get voiceCommandsComingSoonSubtitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਘਰ'**
  String get homeSubtitle;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @rateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਦਰ'**
  String get rateSubtitle;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @unknownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਅਣਜਾਣ'**
  String get unknownSubtitle;

  /// No description provided for @profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profit;

  /// No description provided for @profitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਮੁਨਾਫਾ'**
  String get profitSubtitle;

  /// No description provided for @welcomeToApp.
  ///
  /// In en, this message translates to:
  /// **'Welcome to TruckMate'**
  String get welcomeToApp;

  /// No description provided for @welcomeToAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਟਰੱਕਮੇਟ ਵਿੱਚ ਜੀ ਆਇਆਂ ਨੂੰ'**
  String get welcomeToAppSubtitle;

  /// No description provided for @devModeOtp.
  ///
  /// In en, this message translates to:
  /// **'Development Mode - OTP: 123456'**
  String get devModeOtp;

  /// No description provided for @verifyAndLogin.
  ///
  /// In en, this message translates to:
  /// **'Verify & Login'**
  String get verifyAndLogin;

  /// No description provided for @verifyAndLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਪੁਸ਼ਟੀ ਕਰੋ ਅਤੇ ਲੌਗਇਨ ਕਰੋ'**
  String get verifyAndLoginSubtitle;

  /// No description provided for @changePhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Change Phone Number'**
  String get changePhoneNumber;

  /// No description provided for @changePhoneNumberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਫ਼ੋਨ ਨੰਬਰ ਬਦਲੋ'**
  String get changePhoneNumberSubtitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Trucking Management for Small Carriers'**
  String get appTagline;

  /// No description provided for @appTaglineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ਛੋਟੇ ਕੈਰੀਅਰਾਂ ਲਈ ਟਰੱਕਿੰਗ ਪ੍ਰਬੰਧਨ'**
  String get appTaglineSubtitle;

  /// No description provided for @confirmReachedDestination.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reached Destination {destination}'**
  String confirmReachedDestination(String destination);

  /// No description provided for @confirmReachedDestinationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm arrival at {destination}'**
  String confirmReachedDestinationSubtitle(String destination);

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location: {lat}, {long}'**
  String currentLocation(String lat, String long);

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location Permission Required'**
  String get locationPermissionRequired;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to confirm arrival.'**
  String get locationPermissionDenied;
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
      <String>['en', 'pa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pa':
      return AppLocalizationsPa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
