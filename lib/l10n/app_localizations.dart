import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

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
    Locale('bn'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('ja'),
    Locale('ko'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh')
  ];

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get documents;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @goPro.
  ///
  /// In en, this message translates to:
  /// **'Go Pro'**
  String get goPro;

  /// No description provided for @unlockAllFeaturesInTheApplication.
  ///
  /// In en, this message translates to:
  /// **'Unlock all features in the application'**
  String get unlockAllFeaturesInTheApplication;

  /// No description provided for @document.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get document;

  /// No description provided for @idCard.
  ///
  /// In en, this message translates to:
  /// **'ID Card'**
  String get idCard;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCode;

  /// No description provided for @barCode.
  ///
  /// In en, this message translates to:
  /// **'Bar Code'**
  String get barCode;

  /// No description provided for @passport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get passport;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

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

  /// No description provided for @galleryPermission.
  ///
  /// In en, this message translates to:
  /// **'Gallery Permission'**
  String get galleryPermission;

  /// No description provided for @accessSecurity.
  ///
  /// In en, this message translates to:
  /// **'Access Security'**
  String get accessSecurity;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @rateUs.
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rateUs;

  /// No description provided for @shareTheApp.
  ///
  /// In en, this message translates to:
  /// **'Share the App'**
  String get shareTheApp;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditions;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// No description provided for @reframe.
  ///
  /// In en, this message translates to:
  /// **'Reframe'**
  String get reframe;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @addPage.
  ///
  /// In en, this message translates to:
  /// **'Add Page'**
  String get addPage;

  /// No description provided for @convert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get convert;

  /// No description provided for @sign.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get sign;

  /// No description provided for @documentsFiles.
  ///
  /// In en, this message translates to:
  /// **'Documents Files'**
  String get documentsFiles;

  /// No description provided for @renameDocument.
  ///
  /// In en, this message translates to:
  /// **'Rename Document'**
  String get renameDocument;

  /// No description provided for @moveDocument.
  ///
  /// In en, this message translates to:
  /// **'Move Document'**
  String get moveDocument;

  /// No description provided for @exportDocument.
  ///
  /// In en, this message translates to:
  /// **'Export Document'**
  String get exportDocument;

  /// No description provided for @deleteDocument.
  ///
  /// In en, this message translates to:
  /// **'Delete Document'**
  String get deleteDocument;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @crop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @a4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get a4;

  /// No description provided for @a5.
  ///
  /// In en, this message translates to:
  /// **'A5'**
  String get a5;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @rotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate Left'**
  String get rotateLeft;

  /// No description provided for @rotateRight.
  ///
  /// In en, this message translates to:
  /// **'Rotate Right'**
  String get rotateRight;

  /// No description provided for @pdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// No description provided for @word.
  ///
  /// In en, this message translates to:
  /// **'WORD'**
  String get word;

  /// No description provided for @jpg.
  ///
  /// In en, this message translates to:
  /// **'JPG'**
  String get jpg;

  /// No description provided for @usePasscode.
  ///
  /// In en, this message translates to:
  /// **'Use Passcode'**
  String get usePasscode;

  /// No description provided for @changePasscode.
  ///
  /// In en, this message translates to:
  /// **'Change Passcode'**
  String get changePasscode;

  /// No description provided for @useFaceId.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID'**
  String get useFaceId;

  /// No description provided for @toEnterTheApplication.
  ///
  /// In en, this message translates to:
  /// **'To enter the application'**
  String get toEnterTheApplication;

  /// No description provided for @changeCurrentPasscode.
  ///
  /// In en, this message translates to:
  /// **'Change Current Passcode'**
  String get changeCurrentPasscode;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @becomeAPremium.
  ///
  /// In en, this message translates to:
  /// **'Become a premium'**
  String get becomeAPremium;

  /// No description provided for @unlimitedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Unlimited documents'**
  String get unlimitedDocuments;

  /// No description provided for @scanAndSaveAsManyDocumentsAsYouNeed.
  ///
  /// In en, this message translates to:
  /// **'Scan and save as many documents as you need'**
  String get scanAndSaveAsManyDocumentsAsYouNeed;

  /// No description provided for @imageToTextOcr.
  ///
  /// In en, this message translates to:
  /// **'Image to Text (OCR)'**
  String get imageToTextOcr;

  /// No description provided for @easyEditTextAndShare.
  ///
  /// In en, this message translates to:
  /// **'Easy edit text and share'**
  String get easyEditTextAndShare;

  /// No description provided for @adsFree.
  ///
  /// In en, this message translates to:
  /// **'Ads free'**
  String get adsFree;

  /// No description provided for @noMoreAdsInTheApp.
  ///
  /// In en, this message translates to:
  /// **'No more ads in the app'**
  String get noMoreAdsInTheApp;

  /// No description provided for @signDocumentsOnTheTop.
  ///
  /// In en, this message translates to:
  /// **'Sign documents on the top'**
  String get signDocumentsOnTheTop;

  /// No description provided for @signScannedDocumentsAnywhere.
  ///
  /// In en, this message translates to:
  /// **'Sign scanned documents anywhere'**
  String get signScannedDocumentsAnywhere;

  /// No description provided for @noLimitsOnExport.
  ///
  /// In en, this message translates to:
  /// **'No limits on export'**
  String get noLimitsOnExport;

  /// No description provided for @shareFilesInTxtFormatWithoutRestrictions.
  ///
  /// In en, this message translates to:
  /// **'Share files in TXT format without restrictions'**
  String get shareFilesInTxtFormatWithoutRestrictions;

  /// No description provided for @passcodeProtection.
  ///
  /// In en, this message translates to:
  /// **'Passcode protection'**
  String get passcodeProtection;

  /// No description provided for @keepYourDataPasswordProtected.
  ///
  /// In en, this message translates to:
  /// **'Keep your data password protected'**
  String get keepYourDataPasswordProtected;

  /// No description provided for @unlimitedUse1Week199Week.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Use 1 week, \$1.99/Week'**
  String get unlimitedUse1Week199Week;

  /// No description provided for @continuee.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continuee;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsOfUse;

  /// No description provided for @createNewFolder.
  ///
  /// In en, this message translates to:
  /// **'Create New Folder'**
  String get createNewFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get folderName;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @documentFiles.
  ///
  /// In en, this message translates to:
  /// **'Document Files'**
  String get documentFiles;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get draw;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @pleaseSelectImagesOnly.
  ///
  /// In en, this message translates to:
  /// **'Please select images only'**
  String get pleaseSelectImagesOnly;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @noDataFound.
  ///
  /// In en, this message translates to:
  /// **'No data Found'**
  String get noDataFound;

  /// No description provided for @pleaseSelectFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select First'**
  String get pleaseSelectFirst;

  /// No description provided for @noDirectoryFound.
  ///
  /// In en, this message translates to:
  /// **'No Directory Found'**
  String get noDirectoryFound;

  /// No description provided for @textCopied.
  ///
  /// In en, this message translates to:
  /// **'Text Copied'**
  String get textCopied;

  /// No description provided for @pleaseSelectOneTextOnly.
  ///
  /// In en, this message translates to:
  /// **'Please select One Text Only'**
  String get pleaseSelectOneTextOnly;

  /// No description provided for @areYouSureYouWantToDeleteTheSelectedItems.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete the selected items ?'**
  String get areYouSureYouWantToDeleteTheSelectedItems;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @addSignature.
  ///
  /// In en, this message translates to:
  /// **'Add Signature'**
  String get addSignature;

  /// No description provided for @backPart.
  ///
  /// In en, this message translates to:
  /// **'Back Part'**
  String get backPart;

  /// No description provided for @docScanner.
  ///
  /// In en, this message translates to:
  /// **'Doc Scanner'**
  String get docScanner;

  /// No description provided for @frontPart.
  ///
  /// In en, this message translates to:
  /// **'Front Part'**
  String get frontPart;

  /// No description provided for @createDirectory.
  ///
  /// In en, this message translates to:
  /// **'Create Directory'**
  String get createDirectory;

  /// No description provided for @selectDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select Directory'**
  String get selectDirectory;

  /// No description provided for @enterDirectoryName.
  ///
  /// In en, this message translates to:
  /// **'Enter Directory Name'**
  String get enterDirectoryName;

  /// No description provided for @saveImages.
  ///
  /// In en, this message translates to:
  /// **'Save Images'**
  String get saveImages;

  /// No description provided for @takeAPhotoFirst.
  ///
  /// In en, this message translates to:
  /// **'Take A Photo First'**
  String get takeAPhotoFirst;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// No description provided for @startCropping.
  ///
  /// In en, this message translates to:
  /// **'Start Cropping'**
  String get startCropping;

  /// No description provided for @idCardImagePreview.
  ///
  /// In en, this message translates to:
  /// **'ID Card Image Preview'**
  String get idCardImagePreview;

  /// No description provided for @errorReadingFile.
  ///
  /// In en, this message translates to:
  /// **'Error reading file'**
  String get errorReadingFile;

  /// No description provided for @errorCreatingPdf.
  ///
  /// In en, this message translates to:
  /// **'Error creating PDF'**
  String get errorCreatingPdf;

  /// No description provided for @alreadyExistsInTheDestinationDirectory.
  ///
  /// In en, this message translates to:
  /// **'Already exists in the destination directory'**
  String get alreadyExistsInTheDestinationDirectory;

  /// No description provided for @doesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Does not exist'**
  String get doesNotExist;

  /// No description provided for @pleaseSelectFileOnly.
  ///
  /// In en, this message translates to:
  /// **'Please select File only'**
  String get pleaseSelectFileOnly;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get fileName;

  /// No description provided for @pleaseWriteSomethingToSave.
  ///
  /// In en, this message translates to:
  /// **'Please write something to save'**
  String get pleaseWriteSomethingToSave;

  /// No description provided for @writeFromHere.
  ///
  /// In en, this message translates to:
  /// **'Write from here'**
  String get writeFromHere;

  /// No description provided for @pdfFileSavedAtDocumentDirectory.
  ///
  /// In en, this message translates to:
  /// **'PDF file saved at Document Directory'**
  String get pdfFileSavedAtDocumentDirectory;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @beep.
  ///
  /// In en, this message translates to:
  /// **'Beep'**
  String get beep;

  /// No description provided for @shareWithFriend.
  ///
  /// In en, this message translates to:
  /// **'Share With Friend'**
  String get shareWithFriend;

  /// No description provided for @moreApps.
  ///
  /// In en, this message translates to:
  /// **'More Apps'**
  String get moreApps;

  /// No description provided for @pleaseSelectADirectory.
  ///
  /// In en, this message translates to:
  /// **'Please select a directory'**
  String get pleaseSelectADirectory;

  /// No description provided for @pleaseEnterADirectoryName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a directory name'**
  String get pleaseEnterADirectoryName;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission Denied'**
  String get permissionDenied;

  /// No description provided for @pleaseAllowStoragePermissionToAccessGallery.
  ///
  /// In en, this message translates to:
  /// **'Please allow storage permission to access gallery'**
  String get pleaseAllowStoragePermissionToAccessGallery;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @allowStoragePermission.
  ///
  /// In en, this message translates to:
  /// **'Allow Storage Permission'**
  String get allowStoragePermission;

  /// No description provided for @recognizeText.
  ///
  /// In en, this message translates to:
  /// **'Recognize Text'**
  String get recognizeText;

  /// No description provided for @pdfSavedAtDocumentDirectory.
  ///
  /// In en, this message translates to:
  /// **'PDF saved at Document Directory'**
  String get pdfSavedAtDocumentDirectory;

  /// No description provided for @resize.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get resize;

  /// No description provided for @discardDocument.
  ///
  /// In en, this message translates to:
  /// **'Discard Document !'**
  String get discardDocument;

  /// No description provided for @ifYouLeaveYourProgressWillBeLost.
  ///
  /// In en, this message translates to:
  /// **'If you discard your progress will be lost.'**
  String get ifYouLeaveYourProgressWillBeLost;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noImageFound.
  ///
  /// In en, this message translates to:
  /// **'No Image Found'**
  String get noImageFound;

  /// No description provided for @cannotUndoAnymore.
  ///
  /// In en, this message translates to:
  /// **'Cannot undo anymore'**
  String get cannotUndoAnymore;

  /// No description provided for @pleaseTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Please Take Photo'**
  String get pleaseTakePhoto;

  /// No description provided for @renameFile.
  ///
  /// In en, this message translates to:
  /// **'Rename File'**
  String get renameFile;

  /// No description provided for @pleaseEnterFileName.
  ///
  /// In en, this message translates to:
  /// **'Please enter file name'**
  String get pleaseEnterFileName;

  /// No description provided for @enterFileName.
  ///
  /// In en, this message translates to:
  /// **'Enter file name'**
  String get enterFileName;

  /// No description provided for @doYouWantSaveAllImages.
  ///
  /// In en, this message translates to:
  /// **'Do you want save all images?'**
  String get doYouWantSaveAllImages;

  /// No description provided for @allImagesSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'All images saved successfully'**
  String get allImagesSavedSuccessfully;

  /// No description provided for @exportFiles.
  ///
  /// In en, this message translates to:
  /// **'Export Files'**
  String get exportFiles;

  /// No description provided for @deleteImage.
  ///
  /// In en, this message translates to:
  /// **'Delete Image'**
  String get deleteImage;

  /// No description provided for @doYouWantToDeleteThisImage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to Delete this image?'**
  String get doYouWantToDeleteThisImage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get ok;

  /// No description provided for @noTextFound.
  ///
  /// In en, this message translates to:
  /// **'No text found'**
  String get noTextFound;

  /// No description provided for @thisFeatureRequiresCameraAndMicrophonePermissions.
  ///
  /// In en, this message translates to:
  /// **'This feature requires camera and microphone permissions'**
  String get thisFeatureRequiresCameraAndMicrophonePermissions;

  /// No description provided for @openSettingsPermissionAndAllowCameraAndMicrophonePermissions.
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Permission and allow camera and microphone permissions'**
  String get openSettingsPermissionAndAllowCameraAndMicrophonePermissions;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @pleaseAllowCameraMicrophonePermissionToUseThisFeature.
  ///
  /// In en, this message translates to:
  /// **'Please allow camera microphone permission to use this feature'**
  String get pleaseAllowCameraMicrophonePermissionToUseThisFeature;

  /// No description provided for @allowCameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow Camera Permission'**
  String get allowCameraPermission;

  /// No description provided for @barCodeDetected.
  ///
  /// In en, this message translates to:
  /// **'Barcode Detected'**
  String get barCodeDetected;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to Clipboard'**
  String get copiedToClipboard;

  /// No description provided for @qrCodeDetected.
  ///
  /// In en, this message translates to:
  /// **'QR Code Detected'**
  String get qrCodeDetected;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit !'**
  String get exit;

  /// No description provided for @areYouSureYouWantToExitApp.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To Exit App?'**
  String get areYouSureYouWantToExitApp;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetConnection;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @doYouWantToMakePdf.
  ///
  /// In en, this message translates to:
  /// **'Do you want to make a PDF?'**
  String get doYouWantToMakePdf;

  /// No description provided for @alert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get alert;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @option.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get option;

  /// No description provided for @chooseAnAction.
  ///
  /// In en, this message translates to:
  /// **'Choose an Action'**
  String get chooseAnAction;

  /// No description provided for @doc.
  ///
  /// In en, this message translates to:
  /// **'Doc'**
  String get doc;

  /// No description provided for @exportImages.
  ///
  /// In en, this message translates to:
  /// **'Export Images'**
  String get exportImages;

  /// No description provided for @exportAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get exportAsPdf;

  /// No description provided for @savePdf.
  ///
  /// In en, this message translates to:
  /// **'Save Pdf'**
  String get savePdf;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @saveAtGallery.
  ///
  /// In en, this message translates to:
  /// **'Save at Gallery'**
  String get saveAtGallery;

  /// No description provided for @fileSavedDownloadFolder.
  ///
  /// In en, this message translates to:
  /// **'File Saved Download Folder'**
  String get fileSavedDownloadFolder;

  /// No description provided for @searchHere.
  ///
  /// In en, this message translates to:
  /// **'Search Here'**
  String get searchHere;

  /// No description provided for @noResultFound.
  ///
  /// In en, this message translates to:
  /// **'No Result Found'**
  String get noResultFound;

  /// No description provided for @pleaseAddImageFirst.
  ///
  /// In en, this message translates to:
  /// **'Please add image first'**
  String get pleaseAddImageFirst;

  /// No description provided for @thisLanguageNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This language not supported'**
  String get thisLanguageNotSupported;

  /// No description provided for @imageSavedAtGallery.
  ///
  /// In en, this message translates to:
  /// **'Image Saved at Gallery'**
  String get imageSavedAtGallery;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @folderAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Folder Already Exists'**
  String get folderAlreadyExists;

  /// No description provided for @fileAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'File Already Exists'**
  String get fileAlreadyExists;

  /// No description provided for @conflictAlert.
  ///
  /// In en, this message translates to:
  /// **'Conflict Alert!'**
  String get conflictAlert;

  /// No description provided for @fileConflictAlertContent.
  ///
  /// In en, this message translates to:
  /// **'Some files already exist in this directory. Do you want to duplicate them?'**
  String get fileConflictAlertContent;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @deleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get deleteFile;

  /// No description provided for @downloadFile.
  ///
  /// In en, this message translates to:
  /// **'Download File'**
  String get downloadFile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'bn',
        'en',
        'es',
        'fr',
        'hi',
        'id',
        'ja',
        'ko',
        'ru',
        'tr',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
