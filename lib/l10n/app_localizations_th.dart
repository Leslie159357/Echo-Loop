// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get startupLocalDataErrorTitle => 'ขออภัย เกิดข้อผิดพลาด';

  @override
  String get startupLocalDataErrorMessage =>
      'ไม่สามารถโหลดข้อมูลของคุณได้ตามปกติ โปรดลองอีกครั้ง หากยังพบปัญหา โปรดติดต่อเรา';

  @override
  String get startupLocalDataContactUs => 'ติดต่อเรา';

  @override
  String get startupLocalDataViewLogs => 'ดูบันทึก';

  @override
  String get playbackFailedTitle => 'เล่นไม่สำเร็จ';

  @override
  String get playbackFailedMessage => 'โปรดลองอีกครั้งในภายหลัง';

  @override
  String get premiumTitle => 'Echo Loop Premium';

  @override
  String get premiumTagline => 'AI ไม่จำกัดเพื่อขับเคลื่อนการเรียนรู้ของคุณ';

  @override
  String get aiQuotaExceededGenericTitle => 'โควตา AI ฟรีเดือนนี้ใช้หมดแล้ว';

  @override
  String aiQuotaExceededTitle(String feature) {
    return 'โควตา $feature ฟรีเดือนนี้ใช้หมดแล้ว';
  }

  @override
  String get aiQuotaFeatureTranslation => 'การแปลด้วย AI';

  @override
  String get aiQuotaFeatureAnalysis => 'การวิเคราะห์ประโยคด้วย AI';

  @override
  String get aiQuotaFeatureSenseGroup => 'การแบ่งกลุ่มประโยคด้วย AI';

  @override
  String get aiQuotaFeatureWordAnalysis => 'การวิเคราะห์คำด้วย AI';

  @override
  String get aiQuotaFeatureTranscription => 'การถอดข้อความคำบรรยายด้วย AI';

  @override
  String get aiQuotaFeatureChat => 'ผู้ช่วย AI';

  @override
  String get aiQuotaFeatureRetellReview => 'การตรวจการเล่าเรื่องใหม่ด้วย AI';

  @override
  String get aiQuotaExceededMessage =>
      'อัปเกรดเป็น Premium เพื่อรับโควตา AI และฟีเจอร์ AI แบบไม่จำกัด';

  @override
  String get aiQuotaUnsupportedGenericTitle =>
      'แพ็กเกจฟรีไม่รองรับฟีเจอร์ AI นี้';

  @override
  String aiQuotaUnsupportedTitle(String feature) {
    return 'แพ็กเกจฟรีไม่รองรับ $feature';
  }

  @override
  String get aiQuotaUnsupportedMessage =>
      'อัปเกรดเพื่อปลดล็อกฟีเจอร์นี้และฟีเจอร์ AI อื่นๆ';

  @override
  String get aiQuotaExceededCta => 'อัปเกรดเป็น Premium';

  @override
  String get aiQuotaExceededDismiss => 'เข้าใจแล้ว';

  @override
  String get aiQuotaExceededSubscribe => 'อัปเกรดเลย';

  @override
  String get premiumEntryTitle => 'การสมัครสมาชิก';

  @override
  String get premiumUnavailableOnPlatform =>
      'การสมัครสมาชิกยังไม่พร้อมใช้งานบนแพลตฟอร์มนี้';

  @override
  String get premiumEntryBadgeActive => 'พรีเมียม';

  @override
  String get premiumEntryBadgeUpgrade => 'อัปเกรด';

  @override
  String get premiumActive => 'คุณอยู่ในแพ็กเกจ Premium แล้ว';

  @override
  String get premiumBenefitTranslation => 'การแปลด้วย AI แบบไม่จำกัด';

  @override
  String get premiumBenefitAnalysis => 'การวิเคราะห์ประโยคด้วย AI แบบไม่จำกัด';

  @override
  String get premiumBenefitWordAnalysis =>
      'คำอธิบายคำและวลีด้วย AI แบบไม่จำกัด';

  @override
  String get premiumBenefitTranscription =>
      'การถอดข้อความคำบรรยายด้วย AI เพิ่มขึ้น';

  @override
  String get premiumBenefitAiAssistant => 'แชทกับผู้ช่วย AI แบบไม่จำกัด';

  @override
  String get premiumBenefitPrioritySupport => 'บริการช่วยเหลือแบบเร่งด่วน';

  @override
  String get premiumBenefitSenseGroups =>
      'การแบ่งกลุ่มประโยคด้วย AI แบบไม่จำกัด';

  @override
  String get premiumBenefitRetellReview =>
      'การตรวจการเล่าใหม่ด้วย AI แบบไม่จำกัด';

  @override
  String get premiumSubscribe => 'สมัครสมาชิก';

  @override
  String get premiumBuyOneYear => 'ซื้อหนึ่งปี';

  @override
  String premiumStartTrial(int days) {
    return 'เริ่มทดลองใช้ฟรี $days วัน';
  }

  @override
  String get premiumRestore => 'กู้คืนการซื้อ';

  @override
  String get premiumManage => 'จัดการการสมัครสมาชิก';

  @override
  String get premiumCurrentPlan => 'แพ็กเกจปัจจุบัน';

  @override
  String get premiumPlanMonthly => 'สมาชิกรายเดือน';

  @override
  String get premiumPlanYearly => 'สมาชิกรายปี';

  @override
  String get premiumPlanYearlyOneTime => 'สมาชิกหนึ่งปี';

  @override
  String get premiumPlanLifetime => 'สมาชิกตลอดชีพ';

  @override
  String get premiumPlanGeneric => 'สมาชิก';

  @override
  String get premiumStatusActive => 'ใช้งานอยู่';

  @override
  String get premiumStatusExpiring => 'ใกล้หมดอายุ';

  @override
  String get premiumStatusFixedTerm => 'ซื้อครั้งเดียว';

  @override
  String get premiumStatusLifetime => 'ตลอดชีพ';

  @override
  String premiumRenewsOn(String date) {
    return 'ต่ออายุวันที่ $date';
  }

  @override
  String premiumExpiresOn(String date) {
    return 'หมดอายุวันที่ $date';
  }

  @override
  String premiumValidUntil(String date) {
    return 'ใช้ได้ถึง $date';
  }

  @override
  String get premiumLifetimeAccessNote => 'เข้าถึงได้ตลอดชีพ ไม่ต้องต่ออายุ';

  @override
  String get premiumNoPlans =>
      'ขณะนี้ไม่มีแพ็กเกจให้เลือก โปรดลองอีกครั้งในภายหลัง';

  @override
  String get premiumLoginRequired => 'โปรดลงชื่อเข้าใช้ก่อนสมัครสมาชิก';

  @override
  String get premiumPurchaseLoginRequired => 'โปรดลงชื่อเข้าใช้ก่อนซื้อ';

  @override
  String get premiumRestoreLoginRequired =>
      'โปรดลงชื่อเข้าใช้ก่อนกู้คืนการซื้อ';

  @override
  String get premiumPurchaseFailed => 'การซื้อไม่สำเร็จ โปรดลองอีกครั้ง';

  @override
  String get premiumRestoreAccountMismatch =>
      'การสมัครสมาชิกนี้เชื่อมโยงกับบัญชี Echo Loop อื่น โปรดลงชื่อเข้าใช้บัญชีเดิมแล้วลองอีกครั้ง';

  @override
  String get premiumRestoreNone => 'ไม่พบรายการซื้อที่ต้องการกู้คืน';

  @override
  String get premiumRestored => 'กู้คืนการซื้อแล้ว';

  @override
  String get premiumWebCheckoutCta => 'ดำเนินการต่อเพื่อชำระเงินอย่างปลอดภัย';

  @override
  String get premiumUseWebCheckoutFallback =>
      'ชำระเงินผ่านสโตร์ไม่ได้? ใช้ชำระเงินผ่านเว็บ';

  @override
  String get premiumUseStoreCheckout => 'ดำเนินการต่อด้วยการชำระเงินผ่านสโตร์';

  @override
  String get premiumWebVerifying => 'กำลังรอการยืนยันการชำระเงิน…';

  @override
  String get premiumWebOpenFailed =>
      'ไม่สามารถเปิดหน้าชำระเงินได้ โปรดลองอีกครั้ง';

  @override
  String get premiumRefresh => 'รีเฟรช';

  @override
  String get premiumRefreshStatus => 'รีเฟรชสถานะ Premium';

  @override
  String get premiumPurchasePendingSync =>
      'ซื้อสำเร็จ กำลังซิงก์การเป็นสมาชิกของคุณและจะเปิดใช้งานในไม่ช้า';

  @override
  String get premiumCheckingEntitlement =>
      'กำลังตรวจสอบสถานะการเป็นสมาชิกของคุณ…';

  @override
  String get premiumEntitlementCheckFailed =>
      'เราไม่สามารถยืนยันสถานะการเป็นสมาชิกของคุณได้ โปรดลองอีกครั้งก่อนซื้อ';

  @override
  String get premiumEntitlementUpdated => 'อัปเดตสถานะการเป็นสมาชิกของคุณแล้ว';

  @override
  String get premiumAlreadyEntitledSyncFailed =>
      'พบการสมัครสมาชิกที่ใช้งานอยู่ แต่การซิงก์ล้มเหลว แตะกู้คืนการซื้อที่มุมขวาบน';

  @override
  String get premiumPeriodMonthly => 'รายเดือน';

  @override
  String get premiumPeriodYearly => 'รายปี';

  @override
  String get premiumPeriodYearlyOneTime => '1 ปี · ซื้อครั้งเดียว';

  @override
  String get premiumPeriodLifetime => 'ตลอดชีพ';

  @override
  String get premiumPriceSuffixMonth => '/เดือน';

  @override
  String get premiumPriceSuffixYear => '/ปี';

  @override
  String get premiumPriceSuffixFirstYear => '/ปีแรก';

  @override
  String get premiumPriceSuffixFirstMonth => '/เดือนแรก';

  @override
  String get premiumPriceSuffixLifetime => 'ครั้งเดียว';

  @override
  String get premiumOneTimeYearAccess =>
      'จ่ายครั้งเดียว ใช้ได้ 1 ปี ไม่ต่ออายุอัตโนมัติ';

  @override
  String premiumSavePercent(int percent) {
    return 'ประหยัด $percent%';
  }

  @override
  String premiumPerMonthEquivalent(String price) {
    return '≈ $price/เดือน';
  }

  @override
  String premiumIntroFirstYear(String price) {
    return 'ปีแรก $price';
  }

  @override
  String premiumIntroFirstMonth(String price) {
    return 'เดือนแรก $price';
  }

  @override
  String premiumRenewalPricePerYear(String price) {
    return '$price/ปี';
  }

  @override
  String premiumRenewalPricePerMonth(String price) {
    return '$price/เดือน';
  }

  @override
  String premiumRenewalPricePerPeriod(String price) {
    return '$price';
  }

  @override
  String premiumTryFreeThen(int days, String renewal) {
    return 'ทดลองใช้ฟรี $days วัน จากนั้น $renewal';
  }

  @override
  String premiumOfferThen(String intro, String renewal) {
    return '$intro, จากนั้น $renewal';
  }

  @override
  String premiumSpecialOfferPercent(int percent, String period) {
    return 'ข้อเสนอพิเศษช่วงแรก: ลด $percent% สำหรับ$periodแรก';
  }

  @override
  String premiumSpecialOfferIntro(String intro, String renewal) {
    return 'ข้อเสนอพิเศษช่วงแรก: $intro, จากนั้น $renewal';
  }

  @override
  String get premiumOfferPeriodYear => 'ปี';

  @override
  String get premiumOfferPeriodMonth => 'เดือน';

  @override
  String get premiumTermsShort => 'ข้อกำหนด';

  @override
  String get premiumPrivacyShort => 'ความเป็นส่วนตัว';

  @override
  String get practiceControlModeAuto => 'อัตโนมัติ';

  @override
  String get practiceControlModeManual => 'กำหนดเอง';

  @override
  String get player => 'เครื่องเล่น';

  @override
  String get account => 'บัญชี';

  @override
  String get chinaRoutingIndicatorTooltip => 'ใช้เส้นทางบริการภูมิภาคจีน';

  @override
  String get settings => 'การตั้งค่า';

  @override
  String get addAudio => 'เพิ่มเสียง';

  @override
  String get added => 'เพิ่มแล้ว';

  @override
  String get transcript => 'คำบรรยาย';

  @override
  String get playing => 'ล่าสุด';

  @override
  String get delete => 'ลบ';

  @override
  String get deleteAudio => 'ลบเสียง';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get add => 'เพิ่ม';

  @override
  String get selectAudioFile => 'เลือกไฟล์เสียง';

  @override
  String get subtitlePairedBadge => 'คำบรรยายตรงกัน นำเข้าพร้อมกัน';

  @override
  String get selectTranscript => 'เลือกคำบรรยาย (ไม่บังคับ)';

  @override
  String get noTranscript => 'ไม่มีคำบรรยาย';

  @override
  String get playbackMode => 'โหมดเล่น';

  @override
  String get singleSentence => 'ประโยคเดียว';

  @override
  String get playbackSettings => 'การตั้งค่าการเล่น';

  @override
  String get waveformZoom => 'ซูม';

  @override
  String get waveformZoomIn => 'Zoom in';

  @override
  String get waveformZoomOut => 'Zoom out';

  @override
  String get subtitleEditorVideoLoadFailed =>
      'Couldn\'t load the video. You can still edit subtitles.';

  @override
  String waveformLoading(int progress) {
    return 'กำลังโหลดรูปคลื่น $progress%';
  }

  @override
  String get waveformLoadFailed =>
      'ไม่สามารถแสดงรูปคลื่นได้ คุณยังแก้ไขคำบรรยายด้านล่างได้';

  @override
  String get waveformAudioMissing =>
      'ไม่พบเสียง คุณยังแก้ไขคำบรรยายด้านล่างได้';

  @override
  String get waveformRetry => 'ลองอีกครั้ง';

  @override
  String get playbackSpeed => 'ความเร็วการเล่น';

  @override
  String get loopCount => 'จำนวนรอบวน';

  @override
  String get pauseInterval => 'ช่วงพัก';

  @override
  String get play => 'เล่น';

  @override
  String get pause => 'หยุดชั่วคราว';

  @override
  String get stop => 'หยุด';

  @override
  String get previousSentence => 'ประโยคก่อนหน้า';

  @override
  String get nextSentence => 'ประโยคถัดไป';

  @override
  String get removeBookmark => 'ลบบุ๊กมาร์ก';

  @override
  String get addBookmark => 'เพิ่มบุ๊กมาร์ก';

  @override
  String get appearance => 'รูปแบบ';

  @override
  String get subtitleTextSettings => 'Subtitle Text';

  @override
  String get subtitleTextPreview => 'Preview';

  @override
  String get subtitleFontSize => 'Text size';

  @override
  String get subtitleFontSizeDecrease => 'Smaller text';

  @override
  String get subtitleFontSizeIncrease => 'Larger text';

  @override
  String get subtitleFontWeight => 'Weight';

  @override
  String get subtitleFontWeightDecrease => 'Lighter';

  @override
  String get subtitleFontWeightIncrease => 'Bolder';

  @override
  String get themeMode => 'ธีม';

  @override
  String get themeModeSystem => 'ตามระบบ';

  @override
  String get themeModeLight => 'โหมดสว่าง';

  @override
  String get themeModeDark => 'โหมดมืด';

  @override
  String get language => 'ภาษาของแอป';

  @override
  String get languageDescription => 'ภาษาที่ใช้ในอินเทอร์เฟซแอป';

  @override
  String get languageSystem => 'ตามระบบ';

  @override
  String get languageEnglish => 'ภาษาอังกฤษ';

  @override
  String get languageChinese => 'จีนตัวย่อ';

  @override
  String get languageThai => 'ภาษาไทย';

  @override
  String get nativeLanguage => 'ภาษาแม่';

  @override
  String get nativeLanguageDescription => 'ภาษาสำหรับคำแปลและการวิเคราะห์';

  @override
  String get about => 'เกี่ยวกับ';

  @override
  String get version => 'เวอร์ชัน';

  @override
  String get save => 'บันทึก';

  @override
  String get loopSettings => 'การตั้งค่าลูป';

  @override
  String get wholeTextLoop => 'เล่นวนทั้งไฟล์สื่อ';

  @override
  String get singleSentenceLoop => 'วนประโยคเดียว';

  @override
  String get displaySettings => 'การตั้งค่าการแสดงผล';

  @override
  String get showTranscript => 'แสดงคำบรรยาย';

  @override
  String get shortcutKey => 'ปุ่มลัด';

  @override
  String get seconds => 'วินาที';

  @override
  String get singleSentenceMode => 'การฟังแบบเข้มข้น';

  @override
  String get singleSentenceModeDesc => 'แสดงเฉพาะประโยคปัจจุบัน';

  @override
  String get repeatCount => 'จำนวนครั้งที่ทำซ้ำ';

  @override
  String get infiniteRepeat => 'ไม่สิ้นสุด ∞';

  @override
  String get intervalTime => 'ระยะเวลาพัก';

  @override
  String get times => 'ครั้ง';

  @override
  String loopCountValue(int count) {
    return '$count ครั้ง';
  }

  @override
  String loopIntervalValue(int seconds) {
    return '$seconds วินาที';
  }

  @override
  String get sleepTimer => 'ตั้งเวลาหลับ';

  @override
  String sleepTimerMinutes(int count) {
    return '$count นาที';
  }

  @override
  String get sleepTimerRemaining => 'เวลาที่เหลือ';

  @override
  String get sleepTimerOff => 'ปิดตัวจับเวลา';

  @override
  String sleepTimerA11yActive(String time) {
    return 'ตั้งเวลาหลับ เหลือ $time แตะเพื่อปรับ';
  }

  @override
  String get fullText => 'เล่นทั้งหมด';

  @override
  String get bookmarked => 'บันทึกแล้ว';

  @override
  String get noBookmarkedSentences => 'ไม่มีประโยคที่บันทึกไว้';

  @override
  String get tapBookmarkIcon => 'แตะไอคอนบุ๊กมาร์กเพื่อบันทึก';

  @override
  String get noBookmarksHint =>
      'ยังไม่มีประโยคที่บันทึกไว้ แตะไอคอนบุ๊กมาร์กข้างประโยคเพื่อเพิ่ม';

  @override
  String get bookmarksEmptyReturned =>
      'ไม่มีประโยคที่บันทึกไว้เหลืออยู่ สลับเป็นโหมดเล่นทั้งหมดแล้ว';

  @override
  String get listMode => 'โหมดรายการ';

  @override
  String get copy => 'คัดลอก';

  @override
  String get copied => 'คัดลอกไปยังคลิปบอร์ดแล้ว';

  @override
  String get sentenceMenuSave => 'บันทึกประโยค';

  @override
  String get sentenceMenuUnsave => 'เลิกบันทึกประโยค';

  @override
  String get sentenceMenuExplain => 'คำอธิบายจาก AI';

  @override
  String get sentenceMenuSaved => 'บันทึกประโยคแล้ว';

  @override
  String get sentenceMenuUnsaved => 'เลิกบันทึกประโยคแล้ว';

  @override
  String get sentenceMenuActionFailed =>
      'ไม่สามารถดำเนินการนี้ได้ โปรดลองอีกครั้ง';

  @override
  String get sentenceAudioUnavailable =>
      'ไฟล์เสียงไม่พร้อมใช้งาน จึงไม่สามารถเล่นได้';

  @override
  String get sentenceDetailLoadFailed =>
      'ไม่สามารถโหลดคำบรรยายได้ โปรดลองอีกครั้ง';

  @override
  String get sentenceDetailRetry => 'ลองอีกครั้ง';

  @override
  String get enableAutoScroll => 'เปิดใช้เลื่อนอัตโนมัติ';

  @override
  String get audioFileNotFound => 'ไม่พบไฟล์เสียง ไฟล์อาจถูกลบไปแล้ว';

  @override
  String get pickAudioFileFailed => 'เลือกไฟล์เสียงไม่สำเร็จ';

  @override
  String get addAudioFailed => 'เพิ่มเสียงไม่สำเร็จ';

  @override
  String audioUnsupportedFormat(String ext) {
    return 'รูปแบบเสียงไม่รองรับ: $ext รองรับเฉพาะ MP3, WAV, M4A, AAC, FLAC';
  }

  @override
  String get audioErrorUnsupportedTitle => 'รูปแบบเสียงไม่รองรับ';

  @override
  String get audioErrorNoAudioTitle => 'ยังไม่ได้เลือกไฟล์เสียง';

  @override
  String get audioNoAudioSelected =>
      'คำบรรยายจะถูกนำเข้าพร้อมกับไฟล์เสียง โปรดเลือกไฟล์เสียงด้วย — MP3, WAV, M4A, AAC, FLAC';

  @override
  String get audioErrorGenericTitle => 'เพิ่มเสียงไม่สำเร็จ';

  @override
  String get pickTranscriptFileFailed => 'เลือกไฟล์คำบรรยายไม่สำเร็จ';

  @override
  String subtitleUnsupportedFormat(String ext) {
    return 'รูปแบบคำบรรยายไม่รองรับ: .$ext รองรับเฉพาะไฟล์ SRT และ VTT';
  }

  @override
  String get subtitleFormatInvalid =>
      'รูปแบบคำบรรยายไม่ถูกต้อง รองรับเฉพาะไฟล์ SRT และ VTT มาตรฐาน';

  @override
  String get subtitleFileEmpty =>
      'ไฟล์คำบรรยายว่างเปล่าหรือเสียหาย — ไม่พบรายการคำบรรยาย';

  @override
  String get subtitleErrorUnsupportedTitle => 'รูปแบบคำบรรยายไม่รองรับ';

  @override
  String get subtitleErrorInvalidTitle => 'รูปแบบคำบรรยายไม่ถูกต้อง';

  @override
  String get subtitleErrorEmptyTitle => 'ไม่พบรายการคำบรรยาย';

  @override
  String get subtitleErrorGenericTitle => 'อัปโหลดไม่สำเร็จ';

  @override
  String get fileExists => 'ไฟล์มีอยู่แล้ว';

  @override
  String get back => 'ย้อนกลับ';

  @override
  String get ok => 'ตกลง';

  @override
  String addedOn(String date) {
    return 'เพิ่มเมื่อ: $date';
  }

  @override
  String updatedOn(String date) {
    return 'อัปเดต $date';
  }

  @override
  String get collections => 'คอลเลกชัน';

  @override
  String get collection => 'คอลเลกชัน';

  @override
  String get createCollection => 'สร้างคอลเลกชัน';

  @override
  String get newCollectionOptionTitle => 'คอลเลกชันใหม่';

  @override
  String get newCollectionOptionDescription => 'เพิ่มเสียงหรือวิดีโอ';

  @override
  String get collectionName => 'ชื่อคอลเลกชัน';

  @override
  String get enterCollectionName => 'กรอกชื่อคอลเลกชัน';

  @override
  String get noCollectionsYet => 'ยังไม่มีคอลเลกชัน';

  @override
  String get tapToCreateCollection => 'แตะ + เพื่อสร้างคอลเลกชันแรก';

  @override
  String get deleteCollection => 'ลบคอลเลกชัน';

  @override
  String deleteCollectionConfirm(String name) {
    return 'แน่ใจหรือไม่ว่าต้องการลบ \"$name\"?';
  }

  @override
  String get deleteCollectionDeleteAudioHint =>
      'สื่อการเรียนรู้ในคอลเลกชันนี้และบันทึกการเรียนรู้จะถูกลบไปด้วย สื่อที่อยู่ในคอลเลกชันอื่นจะไม่ได้รับผลกระทบ';

  @override
  String get renameCollection => 'เปลี่ยนชื่อ';

  @override
  String get editCollection => 'Edit';

  @override
  String get editCollectionTitle => 'Edit Collection';

  @override
  String get collectionCoverAdd => 'Add cover';

  @override
  String get collectionCoverChange => 'Change image';

  @override
  String get collectionCoverRemove => 'Remove cover';

  @override
  String get collectionCoverCropTitle => 'Crop Cover';

  @override
  String get collectionSaveFailed => 'Couldn\'t save. Please try again.';

  @override
  String get pinCollection => 'ปักหมุดไว้ด้านบน';

  @override
  String get unpinCollection => 'เลิกปักหมุด';

  @override
  String get pinAudio => 'ปักหมุดไว้ด้านบน';

  @override
  String get unpinAudio => 'เลิกปักหมุด';

  @override
  String get sortByNameAsc => 'ชื่อ (A-Z)';

  @override
  String get sortByNameDesc => 'ชื่อ (Z-A)';

  @override
  String get sortByDateAsc => 'เก่าสุดก่อน';

  @override
  String get sortByDateDesc => 'ใหม่สุดก่อน';

  @override
  String get sortDefault => 'ค่าเริ่มต้น';

  @override
  String get sortByOriginalDateAsc => 'เผยแพร่เก่าสุด';

  @override
  String get sortByOriginalDateDesc => 'เผยแพร่ล่าสุด';

  @override
  String publishedOn(String date) {
    return 'เผยแพร่ $date';
  }

  @override
  String get discoverEntryTitleA => 'สำรวจแหล่งเรียนรู้';

  @override
  String get discoverEntrySubtitleA =>
      'พอดแคสต์, TOEFL, IELTS, CET-4/6, การล่าม...';

  @override
  String get communityCollectionEmpty => 'คอลเลกชันนี้ยังไม่มีเสียง';

  @override
  String communityCollectionAuthor(String nickname) {
    return 'โดย $nickname';
  }

  @override
  String get communityCollectionUnknownAuthor => 'ไม่ทราบผู้เขียน';

  @override
  String communityCollectionUploader(String nickname) {
    return 'อัปโหลดโดย $nickname';
  }

  @override
  String get communityCollectionUnknownUploader => 'ไม่ทราบผู้อัปโหลด';

  @override
  String get communityCollectionShowMore => 'เพิ่มเติม';

  @override
  String get communityCollectionShowLess => 'ย่อ';

  @override
  String get sortCollections => 'เรียงลำดับ';

  @override
  String get listView => 'มุมมองรายการ';

  @override
  String audioCount(int count) {
    return '$count รายการ';
  }

  @override
  String get collectionNameEmpty => 'ชื่อคอลเลกชันต้องไม่ว่าง';

  @override
  String get collectionNameExists => 'มีคอลเลกชันชื่อนี้อยู่แล้ว';

  @override
  String get addAudioToCollection => 'เพิ่มเสียงหรือวิดีโอ';

  @override
  String get removeFromCollection => 'นำออกจากคอลเลกชัน';

  @override
  String removeFromCollectionConfirm(String name) {
    return 'นำ \"$name\" ออกจากคอลเลกชันนี้หรือไม่?';
  }

  @override
  String get permanentlyDeleteAudio => 'ลบเสียงอย่างถาวร';

  @override
  String get permanentlyDeleteAudioHint => 'นำเสียงออกจากทุกคอลเลกชัน';

  @override
  String audioBelongsToCollections(String names) {
    return 'อยู่ใน: $names ด้วย';
  }

  @override
  String get audioNotInOtherCollections =>
      'ไม่ได้อยู่ในคอลเลกชันอื่น — ลบได้อย่างปลอดภัย';

  @override
  String selectedCount(int count) {
    return 'เลือกแล้ว $count';
  }

  @override
  String get selectAll => 'เลือกทั้งหมด';

  @override
  String get deselectAll => 'ยกเลิกเลือกทั้งหมด';

  @override
  String removeFromCollectionBatch(int count) {
    return 'นำ $count ออกจากคอลเลกชัน';
  }

  @override
  String permanentlyDeleteBatch(int count) {
    return 'ลบเสียง $count รายการอย่างถาวร';
  }

  @override
  String get permanentlyDeleteBatchHint => 'นำเสียงออกจากทุกคอลเลกชัน';

  @override
  String get removeFromCollectionBatchHint =>
      'นำออกจากคอลเลกชันนี้เท่านั้น; ไฟล์เสียงจะยังคงอยู่';

  @override
  String get emptyCollection => 'คอลเลกชันนี้ยังไม่มีเนื้อหา';

  @override
  String get collectionSearchHint => 'Search this collection';

  @override
  String get collectionSearchEmpty => 'No matching content';

  @override
  String get collectionSearchTooltip => 'Search';

  @override
  String get collectionSearchClearTooltip => 'Clear';

  @override
  String get librarySearchTooltip => 'Search';

  @override
  String get librarySearchHint => 'Search collections and audio';

  @override
  String get librarySearchEmpty => 'No matching collections or audio';

  @override
  String get renameAudio => 'เปลี่ยนชื่อ';

  @override
  String get audioName => 'ชื่อเสียง';

  @override
  String get study => 'เรียน';

  @override
  String get favorites => 'บันทึกไว้';

  @override
  String get profile => 'โปรไฟล์';

  @override
  String get studyComingSoon => 'ฟีเจอร์การเรียนเร็วๆ นี้';

  @override
  String get firstStudy => 'รอบแรก';

  @override
  String get review => 'ทบทวน';

  @override
  String stepProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String get stepBlindListening => 'ฟังโดยไม่มีคำบรรยาย';

  @override
  String get stepBlindListeningDesc =>
      'ฟังเสียง/วิดีโอทั้งหมดโดยไม่มีคำบรรยาย จับใจความสำคัญ.';

  @override
  String get stepIntensiveListening => 'ฟังทีละประโยค';

  @override
  String get stepIntensiveListeningDesc =>
      'ฟังทีละประโยคพร้อมหยุดอัตโนมัติ สำหรับประโยคที่ยาก ให้แตะ “Unclear” เพื่อบันทึกและดูการวิเคราะห์จาก AI';

  @override
  String get stepShadowing => 'ฟังและพูดตาม';

  @override
  String get stepShadowingDesc =>
      'พูดตามประโยคที่บันทึกไว้ โดยค่าเริ่มต้นแต่ละประโยคจะเล่นสามครั้ง';

  @override
  String get stepRetelling => 'ฟังและเล่าใหม่';

  @override
  String get stepRetellingDesc =>
      'ฟังและเล่าใหม่ทีละช่วง ใช้บทถอดเสียงต้นฉบับหรือเล่าใหม่ด้วยคำพูดของคุณเอง';

  @override
  String get stepFullTextRetelling => 'เล่าใหม่ทั้งบท';

  @override
  String get warmUpCardTitle => 'ฟังอุ่นเครื่อง';

  @override
  String get warmUpCardSubtitle =>
      'ฟังหนึ่งครั้งเพื่อจับใจความสำคัญ ไม่จำเป็นต้องฟังทุกคำ';

  @override
  String get warmUpCardBadge => 'แนะนำให้เริ่มก่อน';

  @override
  String get reviewRound0 => 'ทบทวน 1';

  @override
  String get reviewRound1 => 'ทบทวน 2';

  @override
  String get reviewRound2 => 'ทบทวน 3';

  @override
  String get reviewRound4 => 'ทบทวน 4';

  @override
  String get reviewRound7 => 'ทบทวน 5';

  @override
  String get reviewRound14 => 'ทบทวน 6';

  @override
  String get reviewRound28 => 'ทบทวน 7';

  @override
  String reviewUnlockIn(int days) {
    return 'ปลดล็อกใน $days วัน';
  }

  @override
  String reviewUnlockInHours(int hours) {
    return 'ปลดล็อกใน $hours ชั่วโมง';
  }

  @override
  String get unlockReviewNow => 'ปลดล็อกเลย';

  @override
  String get startLearning => 'เริ่มฝึก';

  @override
  String get continueLearning => 'ฝึกต่อ';

  @override
  String get learningInProgress => 'กำลังฝึก';

  @override
  String get learningCompleted => 'เสร็จแล้ว';

  @override
  String get learningNotStarted => 'Not started';

  @override
  String get reviewReady => 'พร้อมทบทวน';

  @override
  String get blindListenBriefingTitle => 'ฟังโดยไม่มีคำบรรยาย';

  @override
  String get blindListenBriefingSubtitle => 'รอบแรก - ฟังโดยไม่มีคำบรรยาย';

  @override
  String blindListenBriefingReviewSubtitle(int round) {
    return 'ทบทวน $round - ฟังโดยไม่มีคำบรรยาย';
  }

  @override
  String get blindListenBriefingTip =>
      'ท้าทายตัวเอง: ฟังโดยไม่มีคำบรรยายและจับใจความ';

  @override
  String get startPractice => 'เริ่มฝึก';

  @override
  String get blindListenAppBarTitle => 'ฟังโดยไม่มีคำบรรยาย';

  @override
  String get blindListenComplete => 'ฟังโดยไม่มีคำบรรยายเสร็จแล้ว';

  @override
  String blindListenPassInfo(int count) {
    return 'ฟังแล้ว $count ครั้ง';
  }

  @override
  String get selectDifficulty => 'ยากแค่ไหน?';

  @override
  String get selectDifficultyRequired => 'เลือกระดับความยากเพื่อดำเนินการต่อ';

  @override
  String get listenAgain => 'ฟังอีกครั้ง';

  @override
  String get practiceAgain => 'ฝึกอีกครั้ง';

  @override
  String get nextStage => 'ถัดไป';

  @override
  String get skipCountdown => 'ข้าม';

  @override
  String audioDuration(String duration) {
    return 'ระยะเวลา: $duration';
  }

  @override
  String estimatedMinutes(int minutes) {
    return 'ประมาณ $minutes นาที';
  }

  @override
  String get estimatedLessThanOneMinute => 'ประมาณ < 1 นาที';

  @override
  String get exitBlindListenTitle => 'ออกจากการฟัง?';

  @override
  String get exitBlindListenMessage =>
      'เสียงยังเล่นอยู่ แน่ใจหรือไม่ว่าต้องการออก?';

  @override
  String get confirmExit => 'ออก';

  @override
  String get library => 'คลัง';

  @override
  String get myLibrary => 'คลังของฉัน';

  @override
  String get collectionsTab => 'คอลเลกชัน';

  @override
  String get audioTab => 'เสียง';

  @override
  String get manageCollections => 'จัดการคอลเลกชัน';

  @override
  String get noAudioItems => 'ยังไม่มีไฟล์เสียง';

  @override
  String get noAudioItemsHint => 'นำเข้าไฟล์เสียงเพื่อเริ่มฝึก';

  @override
  String get done => 'เสร็จ';

  @override
  String get sortAudio => 'เรียงลำดับ';

  @override
  String deleteAudioConfirm(String name) {
    return 'ลบ \"$name\" อย่างถาวร?';
  }

  @override
  String deleteAudioConfirmKeepFile(String name) {
    return 'แน่ใจหรือไม่ว่าต้องการลบ \"$name\"? ไฟล์เสียงนี้ถูกใช้ร่วมกับรายการอื่นและจะถูกเก็บไว้';
  }

  @override
  String get uploadTranscript => 'อัปโหลดคำบรรยาย';

  @override
  String get replaceTranscriptTitle => 'แทนที่คำบรรยาย';

  @override
  String get replaceTranscriptMessage =>
      'มีไฟล์คำบรรยายอยู่แล้ว ต้องการแทนที่หรือไม่?';

  @override
  String get replace => 'แทนที่';

  @override
  String sentenceCountLabel(int count) {
    return '$count ประโยค';
  }

  @override
  String wordCountLabel(int count) {
    return '$count คำ';
  }

  @override
  String get noTranscriptWarning => 'เสียงนี้ยังไม่มีคำบรรยาย';

  @override
  String get intensiveListenAppBarTitle => 'ฟังทีละประโยค';

  @override
  String intensiveListenProgress(int current, int total) {
    return 'ประโยค $current/$total';
  }

  @override
  String get intensiveListenPeek => 'แอบดูคำบรรยาย';

  @override
  String get intensiveListenHideSubtitle => 'ซ่อนคำบรรยาย';

  @override
  String get intensiveListenUnclear => 'ไม่ชัดเจน';

  @override
  String get intensiveListenAutoMarkedDifficult =>
      'บันทึกอัตโนมัติ แตะเพื่อเลิกทำ';

  @override
  String get intensiveListenMarkedDifficult => 'เลิกบันทึก';

  @override
  String get intensiveListenNotDifficult => 'บันทึก';

  @override
  String get aiTranslation => 'คำแปล';

  @override
  String get aiAnalysis => 'วิเคราะห์';

  @override
  String get aiLoadFailed => 'โหลดไม่สำเร็จ แตะเพื่อลองใหม่';

  @override
  String get aiTranslationFailed => 'แปลไม่สำเร็จ โปรดลองใหม่';

  @override
  String get aiAnalysisFailed => 'วิเคราะห์ไม่สำเร็จ โปรดลองใหม่';

  @override
  String get aiRetry => 'ลองใหม่';

  @override
  String get aiGrammar => 'ไวยากรณ์';

  @override
  String get aiVocabulary => 'คำศัพท์สำคัญ';

  @override
  String get aiListening => 'เคล็ดลับการฟัง';

  @override
  String get intensiveListenWordDictNotFound => 'ไม่พบคำในพจนานุกรม';

  @override
  String get intensiveListenReplayingWithSubtitle => 'ฟังอีกครั้งเพื่อให้จำได้';

  @override
  String get intensiveListenCompleteTitle => 'ฟังทีละประโยคเสร็จสิ้น';

  @override
  String get intensiveListenCompleteHint =>
      'ทบทวนต่อด้วยการทบทวนแบบเว้นช่วงเพื่อให้เชี่ยวชาญเต็มที่';

  @override
  String get statSentences => 'ประโยค';

  @override
  String get statDifficultSentences => 'ท้าทาย';

  @override
  String get statParagraphs => 'ส่วน';

  @override
  String get exitIntensiveListenTitle => 'ออกจากการฟังทีละประโยค?';

  @override
  String get exitIntensiveListenMessage =>
      'ความคืบหน้าจะถูกบันทึกไว้ ทำต่อจากจุดเดิมได้';

  @override
  String get intensiveListenBriefingTitle => 'ฟังทีละประโยค';

  @override
  String get intensiveListenBriefingTip =>
      'ฟังทีละประโยค แตะ \'ไม่ชัดเจน\' เพื่อดูข้อความและบทวิเคราะห์';

  @override
  String intensiveListenBriefingSentenceCount(int count) {
    return '$count ประโยค';
  }

  @override
  String get intensiveListenNoSubtitle => 'ไม่มีคำบรรยาย';

  @override
  String get intensiveListenNoSubtitleMessage =>
      'ไฟล์เสียงนี้ไม่มีคำบรรยาย โปรดอัปโหลดไฟล์คำบรรยายก่อน';

  @override
  String get intensiveListenSettings => 'การตั้งค่า';

  @override
  String get intensiveListenRepeatCount => 'จำนวนซ้ำต่อประโยค';

  @override
  String get intensiveListenAnnotationReplayUsesRepeatCount =>
      'จำนวนซ้ำในหน้าคำอธิบาย';

  @override
  String intensiveListenRepeatCountValue(int count) {
    return '$count ครั้ง';
  }

  @override
  String get intensiveListenPauseLabel => 'หยุดระหว่างประโยค';

  @override
  String get intensiveListenPauseSmart => 'อัตโนมัติ';

  @override
  String get intensiveListenPauseFixed => 'คงที่';

  @override
  String get intensiveListenPauseMultiplierMode => 'ตัวคูณ';

  @override
  String get intensiveListenSettingsTemporaryHint =>
      'การตั้งค่าจะถูกจำไว้สำหรับครั้งถัดไป';

  @override
  String get intensiveListenPauseSmartDesc =>
      'ปรับอัตโนมัติตามความยาก ความยาวประโยค และขั้นการเรียนรู้';

  @override
  String get intensiveListenControlModeAutoDesc =>
      'วนซ้ำอัตโนมัติ หยุดอัตโนมัติ ไปต่ออัตโนมัติ';

  @override
  String get intensiveListenControlModeManualDesc =>
      'ทำซ้ำตามที่ตั้งค่าไว้ แตะเพื่อไปต่อ';

  @override
  String intensiveListenPauseMultiplierValue(String value) {
    return '$value เท่า';
  }

  @override
  String get intensiveListenPauseMultiplierLabel => 'ตัวคูณ';

  @override
  String difficultyLabel(String difficulty) {
    return 'ระดับความยาก: $difficulty';
  }

  @override
  String get completeFirstStudy => 'รอบแรกเสร็จสิ้น';

  @override
  String get completeReview => 'ทบทวนเสร็จสิ้น';

  @override
  String stepProgressLabel(int current, int total, String stage) {
    return 'ขั้นที่ $current/$total ($stage)';
  }

  @override
  String get manageTags => 'จัดการแท็ก';

  @override
  String get noTagsYet => 'ยังไม่มีแท็ก';

  @override
  String get createTag => 'สร้างแท็ก';

  @override
  String get tagName => 'ชื่อแท็ก';

  @override
  String get enterTagName => 'ป้อนชื่อแท็ก';

  @override
  String get selectColor => 'เลือกสี';

  @override
  String get deleteTag => 'ลบแท็ก';

  @override
  String deleteTagConfirm(String name) {
    return 'คุณแน่ใจหรือไม่ว่าต้องการลบ \"$name\"? แท็กนี้จะถูกนำออกจากไฟล์เสียงทั้งหมด';
  }

  @override
  String get listenAndRepeatAppBarTitle => 'ฟังและพูดตาม';

  @override
  String listenAndRepeatProgress(int current, int total) {
    return 'ประโยค $current/$total';
  }

  @override
  String get listenAndRepeatListenHint => 'ฟังแล้วพูดตาม';

  @override
  String get listenAndRepeatRecordingInProgress => 'กำลังบันทึก...';

  @override
  String get listenAndRepeatAnalyzing => 'กำลังวิเคราะห์...';

  @override
  String get listenAndRepeatRatingPerfect => 'สมบูรณ์แบบ!';

  @override
  String get listenAndRepeatRatingExcellent => 'ยอดเยี่ยม';

  @override
  String get listenAndRepeatRatingGood => 'ดี';

  @override
  String get listenAndRepeatRatingFair => 'พอใช้';

  @override
  String get listenAndRepeatRatingKeepGoing => 'ทำต่อไป';

  @override
  String get listenAndRepeatRecognitionNoEnglish => 'ไม่พบเสียงพูดภาษาอังกฤษ';

  @override
  String get listenAndRepeatRecognitionPermissionDenied =>
      'ต้องอนุญาตให้ใช้ไมโครโฟนหรือการรู้จำเสียงพูด';

  @override
  String get listenAndRepeatRecognitionUnavailable =>
      'การรู้จำเสียงพูดไม่พร้อมใช้งานบนอุปกรณ์นี้';

  @override
  String get listenAndRepeatRecognitionError => 'ข้อผิดพลาดในการรู้จำ';

  @override
  String get listenAndRepeatRecordingOnly => 'กำลังบันทึก';

  @override
  String get listenAndRepeatCompleteTitle => 'ฟังและพูดตามเสร็จสิ้น';

  @override
  String get exitListenAndRepeatTitle => 'ออกจากฟังและพูดตาม?';

  @override
  String get exitListenAndRepeatMessage =>
      'ความคืบหน้าของคุณจะถูกบันทึกไว้ คุณสามารถทำต่อจากจุดที่ค้างไว้ได้';

  @override
  String get listenAndRepeatBriefingTitle => 'ฟังและพูดตาม';

  @override
  String get listenAndRepeatBriefingTip =>
      'ฟังก่อน แล้วพูดตามในช่วงหยุดพัก โดยค่าเริ่มต้น ประโยคที่บันทึกไว้แต่ละประโยคจะเล่นสามครั้ง';

  @override
  String get listenAndRepeatScopeLabel => 'ขอบเขตการพูดตาม';

  @override
  String get listenAndRepeatScopeFullText => 'ข้อความเต็ม';

  @override
  String get listenAndRepeatScopeDifficultOnly => 'เฉพาะที่บันทึกไว้';

  @override
  String get listenAndRepeatNoSavedSentencesNoNeed => 'ไม่มีประโยคที่บันทึกไว้';

  @override
  String listenAndRepeatBriefingSentenceCount(int count) {
    return '$count ประโยค';
  }

  @override
  String listenAndRepeatBriefingDifficultCount(int count) {
    return '$count ประโยคที่บันทึกไว้';
  }

  @override
  String listenAndRepeatBriefingPlayCount(int count) {
    return 'เล่น $count ครั้งต่อประโยค';
  }

  @override
  String get listenAndRepeatSettings => 'ตั้งค่าการพูดตาม';

  @override
  String get listenAndRepeatSettingsTemporaryHint =>
      'การตั้งค่ามีผลเฉพาะเซสชันนี้';

  @override
  String get listenAndRepeatControlModeLabel => 'โหมดควบคุม';

  @override
  String get listenAndRepeatControlModeAuto => 'อัตโนมัติ';

  @override
  String get listenAndRepeatControlModeManual => 'กำหนดเอง';

  @override
  String get listenAndRepeatControlModeAutoDesc =>
      'บันทึกอัตโนมัติ หยุดอัตโนมัติ เล่นถัดไปอัตโนมัติ';

  @override
  String get listenAndRepeatControlModeManualDesc =>
      'แตะเพื่อบันทึก แตะเพื่อหยุด แตะเพื่อเล่นประโยคถัดไป';

  @override
  String get listenAndRepeatPauseSmartDesc =>
      'ปรับอัตโนมัติตามความยาก ความยาวประโยค และขั้นการเรียนรู้';

  @override
  String sentenceDuration(String duration) {
    return '$duration วินาที';
  }

  @override
  String difficultSentenceCount(int count) {
    return '$count ประโยคที่ยาก';
  }

  @override
  String intensiveListenPassInfo(int count) {
    return 'ฝึกแล้ว $count ครั้ง';
  }

  @override
  String shadowingPassInfo(int count) {
    return 'ฝึกแล้ว $count ครั้ง';
  }

  @override
  String get retellBriefingTitle => 'ฟังแล้วเล่าใหม่';

  @override
  String get retellBriefingSubtitle =>
      'ฟังและเล่าใหม่ทีละช่วง ทำตามบทถอดเสียงต้นฉบับหรือใช้คำพูดของคุณเอง คำที่แสดงจะช่วยให้คุณจำสิ่งที่ได้ยิน';

  @override
  String get retellBriefingSentenceLevel => 'ทีละประโยค';

  @override
  String get retellTitle => 'ฟังแล้วเล่าใหม่';

  @override
  String retellParagraphProgress(int current, int total) {
    return 'ช่วง $current/$total';
  }

  @override
  String retellParagraphDuration(String duration) {
    return '$duration วินาที';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '$minutes นาที $seconds วินาที';
  }

  @override
  String get retellPreListenHint => 'ฟังก่อน แล้วเล่าใหม่';

  @override
  String get retellListeningPhase => 'ฟังอย่างตั้งใจ...';

  @override
  String get retellCompleteFreePlay => 'ฝึกเสร็จสิ้น';

  @override
  String get retellCompleteTitle => 'ฟังแล้วเล่าใหม่เสร็จสิ้น';

  @override
  String get retellPracticeAgain => 'ฝึกอีกครั้ง';

  @override
  String get retellExitConfirmTitle => 'ออกจากฟังแล้วเล่าใหม่?';

  @override
  String get retellExitConfirmMessage =>
      'ความคืบหน้าของช่วงปัจจุบันจะถูกบันทึกไว้';

  @override
  String get retellDisplayKeywordsOnly => 'บางส่วน';

  @override
  String get retellDisplayShowAll => 'แสดง';

  @override
  String get retellDisplayHideAll => 'ซ่อน';

  @override
  String get retellDisplayHide => 'Hidden';

  @override
  String get retellDisplayShow => 'Visible';

  @override
  String get retellDisplayOriginal => 'Original';

  @override
  String get retellDisplayTranslation => 'Translation';

  @override
  String get retellPromptLanguage => 'Retell with';

  @override
  String get retellPromptLanguageOriginal => 'German';

  @override
  String get retellPromptLanguageTranslation => 'Translation';

  @override
  String get retellPromptLanguageTranslationDesc =>
      'Shows the AI translation instead of the German text, so you can retell in German from the translation.';

  @override
  String get sentenceTranslationLoadFailed =>
      'Translation failed. Tap to retry.';

  @override
  String get sentenceTranslationQuotaExceeded =>
      'AI translation quota used up. Tap to subscribe.';

  @override
  String get retellSettingsTitle => 'ตั้งค่าการเล่าใหม่';

  @override
  String get retellAutoPlaybackPromptTitle =>
      'เล่นเสียงบันทึกของคุณอัตโนมัติหลังเล่าใหม่หรือไม่?';

  @override
  String get retellAutoPlaybackPromptMessage =>
      'เมื่อเปิดใช้งาน เสียงบันทึกของคุณจะเล่นอัตโนมัติหลังการเล่าใหม่แต่ละครั้ง เพื่อให้คุณตรวจสอบการออกเสียงได้ทันที คุณสามารถเปลี่ยนได้ทุกเมื่อในการตั้งค่า';

  @override
  String get retellAutoPlaybackKeepOff => 'ไม่ใช่ตอนนี้';

  @override
  String get retellAutoPlaybackEnable => 'เปิดใช้งาน';

  @override
  String get retellRepeatCount => 'ทำซ้ำต่อช่วง';

  @override
  String get retellPauseMode => 'หยุดพักระหว่างช่วง';

  @override
  String retellPassInfo(int count) {
    return 'ฝึกแล้ว $count ครั้ง';
  }

  @override
  String get retellKeywordMethod => 'คำที่แสดง';

  @override
  String get retellKeywordMethodOff => 'ปิด';

  @override
  String get retellKeywordMethodRandom => 'สุ่ม';

  @override
  String get retellKeywordMethodAi => 'AI';

  @override
  String get retellKeywordMethodAiComingSoon => 'เร็ว ๆ นี้';

  @override
  String get retellKeywordRatio => 'คำที่แสดง';

  @override
  String get pauseModeSmart => 'อัตโนมัติ';

  @override
  String get pauseModeFixed => 'คงที่';

  @override
  String get pauseModeMultiplier => 'ตัวคูณ';

  @override
  String get fixedPauseSeconds => 'เวลาหยุดคงที่';

  @override
  String get pauseMultiplier => 'ตัวคูณ';

  @override
  String get settingsSessionOnly => 'การตั้งค่ามีผลเฉพาะเซสชันปัจจุบัน';

  @override
  String get reviewDifficultPracticeTitle => 'ฝึกประโยคที่บันทึกไว้';

  @override
  String get reviewBlindListenDesc => 'ฟังซ้ำเพื่อดูว่าความเข้าใจดีขึ้นแค่ไหน';

  @override
  String get reviewDifficultPracticeDesc =>
      'ฟังประโยคที่บันทึกไว้อีกครั้ง แล้วพูดซ้ำประโยคที่ยังติดขัด';

  @override
  String get reviewRetellParagraphDesc =>
      'เล่าอีกครั้งเพื่อฝึกความเข้าใจและการถ่ายทอด';

  @override
  String get reviewRetellSummaryDesc =>
      'สรุปเนื้อหาทั้งหมด จับใจความภาพรวม และตรวจสอบว่าคุณเรียนได้ดีแค่ไหน';

  @override
  String get reviewBriefingTipDifficultPractice =>
      'ฟังโดยไม่เปิดคำบรรยายก่อน แล้วฝึกประโยคที่ยังติดขัด';

  @override
  String get reviewBriefingTipRetellSummary => 'สรุปเสียงทั้งหมดใน 3-5 ประโยค';

  @override
  String reviewDifficultPracticeProgress(int current, int total) {
    return 'ประโยค $current/$total';
  }

  @override
  String get reviewDifficultPracticeCompleteTitle =>
      'ฝึกประโยคที่บันทึกไว้เสร็จแล้ว';

  @override
  String get reviewDifficultPracticeNone =>
      'ไม่มีประโยคที่บันทึกไว้ให้ฝึก เสร็จสิ้นอัตโนมัติ';

  @override
  String get exitReviewDifficultPracticeTitle => 'ออกจากการฝึก?';

  @override
  String get exitReviewDifficultPracticeConfirmMessage =>
      'ความคืบหน้าของคุณจะถูกบันทึก และคุณสามารถทำต่อในครั้งถัดไปได้';

  @override
  String get speechRecognition => 'การรู้จำเสียงพูด';

  @override
  String get speechRecognitionNotConfigured => 'ยังไม่ได้ตั้งค่า';

  @override
  String get speechRecognitionEnabled => 'เปิดใช้งาน';

  @override
  String get speechRecognitionDisabled => 'ปิดใช้งาน';

  @override
  String get speechRecognitionDescription =>
      'การรู้จำเสียงช่วยให้คะแนนการฝึกและรองรับการถอดเสียงในเครื่องในอนาคต เลือกโมเดลที่เหมาะกับอุปกรณ์ของคุณ';

  @override
  String get asrEngine => 'ระบบรู้จำเสียง';

  @override
  String get asrBackendPlatform => 'Apple AI';

  @override
  String get asrBackendPlatformDescription =>
      'ใช้การรู้จำเสียงพูดของระบบที่มีมาให้ ไม่ต้องดาวน์โหลด';

  @override
  String get asrBackendOffline => 'Echo Loop AI';

  @override
  String get asrBackendOfflineDescription =>
      'ใช้โมเดล AI ของแอป ใช้งานออฟไลน์ได้หลังจากดาวน์โหลด';

  @override
  String get asrModelFastDescription => 'เร็วที่สุด เหมาะกับอุปกรณ์สเปกต่ำ';

  @override
  String get asrModelBalancedDescription => 'สมดุลระหว่างความแม่นยำและความเร็ว';

  @override
  String get asrModelAccurateDescription =>
      'แม่นยำกว่า แต่มีขนาดใหญ่และช้ากว่า';

  @override
  String get localSpeechRecognition => 'การรู้จำเสียงในเครื่อง';

  @override
  String speechModelSize(String size) {
    return 'ขนาดโมเดล: ~$size';
  }

  @override
  String speechModelApproxSize(String size) {
    return '~$size';
  }

  @override
  String speechModelReady(String size) {
    return 'พร้อม · $size';
  }

  @override
  String get speechModelStatusReady => 'พร้อม';

  @override
  String get speechModelStatusNeedsDownload => 'ดาวน์โหลด';

  @override
  String speechModelDownloading(String progress) {
    return 'กำลังดาวน์โหลด... $progress';
  }

  @override
  String get speechModelDownloadFailed => 'ดาวน์โหลดไม่สำเร็จ แตะเพื่อลองใหม่';

  @override
  String get downloadErrorStorage =>
      'พื้นที่เก็บข้อมูลไม่พอ โปรดเพิ่มพื้นที่แล้วลองใหม่';

  @override
  String get downloadErrorNetwork =>
      'เครือข่ายผิดพลาด ตรวจสอบการเชื่อมต่อแล้วลองใหม่';

  @override
  String get downloadErrorCorrupted =>
      'ตรวจสอบไฟล์ที่ดาวน์โหลดไม่ผ่าน โปรดลองใหม่';

  @override
  String deleteModel(String size) {
    return 'ลบโมเดล ($size)';
  }

  @override
  String get deleteModelAction => 'ลบโมเดล';

  @override
  String get deleteModelConfirmTitle => 'ลบโมเดล?';

  @override
  String deleteModelConfirmMessage(String size) {
    return 'การดำเนินการนี้จะเพิ่มพื้นที่ว่างในการจัดเก็บ $size';
  }

  @override
  String get speechRecognitionRequiredMessage =>
      'การรู้จำเสียงใช้เพื่อประเมินการออกเสียงและการเล่าของคุณโดยอัตโนมัติ ต้องดาวน์โหลดโมเดลก่อนเริ่ม';

  @override
  String get asrModelDownloadRequiredTitle =>
      'จำเป็นต้องมีโมเดลการรู้จำเสียงพูด';

  @override
  String asrModelDownloadEstimate(String size) {
    return 'ขนาดดาวน์โหลดโดยประมาณ: ~$size';
  }

  @override
  String get asrModelDownloadSettingsHint =>
      'คุณสามารถเลือกโมเดลการรู้จำเสียงพูดอื่นได้ในการตั้งค่า';

  @override
  String get asrModelDownloadingTitle => 'กำลังดาวน์โหลดโมเดลการรู้จำเสียงพูด';

  @override
  String asrModelDownloadingMessage(String size) {
    return 'ขนาดดาวน์โหลดโดยประมาณ: ~$size';
  }

  @override
  String asrModelDownloadProgress(String progress) {
    return 'เสร็จแล้ว $progress';
  }

  @override
  String get asrModelDownloadFailedTitle =>
      'ดาวน์โหลดโมเดลการรู้จำเสียงพูดไม่สำเร็จ';

  @override
  String asrModelDownloadFailedMessage(String size) {
    return 'ดาวน์โหลดไม่เสร็จสมบูรณ์ ขนาดดาวน์โหลดโดยประมาณ: ~$size';
  }

  @override
  String get asrDownloadModel => 'ดาวน์โหลดโมเดล';

  @override
  String get later => 'ภายหลัง';

  @override
  String get speechRecognitionNotEnabled =>
      'ยังไม่ได้เปิดใช้งานการรู้จำเสียง เปิดได้ในการตั้งค่า';

  @override
  String get retryDownload => 'ลองใหม่';

  @override
  String get developer => 'นักพัฒนา';

  @override
  String get developerOptionsEnabled => 'เปิดใช้งานตัวเลือกนักพัฒนาแล้ว';

  @override
  String get developerOptionsDisable => 'ปิดใช้งานตัวเลือกนักพัฒนา';

  @override
  String get timeMachine => 'ไทม์แมชชีน';

  @override
  String get timeMachineUseSystemTime => 'ใช้เวลาระบบ';

  @override
  String get timeMachineCurrentTime => 'เวลาดีบั๊ก';

  @override
  String get timeMachineSelectDate => 'เลือกวันที่';

  @override
  String get timeMachineSelectTime => 'เลือกเวลา';

  @override
  String get timeMachineReset => 'ใช้เวลาระบบ';

  @override
  String get manageSubtitles => 'จัดการคำบรรยาย';

  @override
  String get localUpload => 'อัปโหลดจากเครื่อง';

  @override
  String get aiTranscription => 'ถอดเสียงบนคลาวด์';

  @override
  String get aiTranscriptionSubtitle =>
      'แม่นยำกว่า ต้องมีเครือข่าย + ลงชื่อเข้าใช้';

  @override
  String get offlineTranscription => 'ถอดเสียงบนอุปกรณ์';

  @override
  String get offlineTranscriptionSubtitle =>
      'ออฟไลน์ เป็นส่วนตัว ไม่ต้องลงชื่อเข้าใช้';

  @override
  String get transcriptionModelTier => 'โมเดลการรู้จำ';

  @override
  String get localTranscriptionDecoding => 'กำลังถอดรหัสเสียง...';

  @override
  String get localTranscriptionForegroundHint =>
      'โปรดเปิดแอปค้างไว้บนหน้าจอจนกว่าจะเสร็จ — การถอดเสียงจะหยุดชั่วคราวหากคุณสลับแอปหรือล็อกหน้าจอ';

  @override
  String localTranscriptionProgressPercent(int percent) {
    return 'เสร็จแล้ว $percent%';
  }

  @override
  String localTranscriptionModelRequiredMessage(String modelName) {
    return 'การถอดเสียงบนอุปกรณ์ต้องดาวน์โหลดโมเดลเสียงพูด $modelName หนึ่งครั้ง (หลังจากนั้นใช้แบบออฟไลน์ได้)';
  }

  @override
  String get deleteSubtitle => 'ลบคำบรรยาย';

  @override
  String get startTranscription => 'เริ่มถอดเสียง';

  @override
  String get alreadyTranscribedWithOption => 'ถอดเสียงด้วยตัวเลือกนี้แล้ว';

  @override
  String get transcriptionUploading => 'กำลังอัปโหลด...';

  @override
  String get transcriptionCompressing => 'กำลังบีบอัดเสียง...';

  @override
  String get transcriptionProcessing => 'กำลังถอดเสียง...';

  @override
  String get transcriptionComplete => 'เสร็จสิ้น!';

  @override
  String get transcriptionFailed => 'ถอดเสียงไม่สำเร็จ';

  @override
  String get transcriptionErrorConnection => 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';

  @override
  String get transcriptionErrorTimeout => 'คำขอหมดเวลา โปรดลองอีกครั้ง';

  @override
  String get transcriptionErrorServer =>
      'โปรดตรวจสอบไฟล์เสียงแล้วลองอีกครั้งภายหลัง';

  @override
  String get transcriptionErrorUnknown =>
      'โปรดตรวจสอบไฟล์เสียงแล้วลองอีกครั้งภายหลัง';

  @override
  String get transcriptionErrorCompression =>
      'บีบอัดเสียงไม่สำเร็จ โปรดตรวจสอบไฟล์เสียงแล้วลองอีกครั้ง.';

  @override
  String get transcriptionErrorCompressedFileTooLarge =>
      'ไฟล์ที่บีบอัดแล้วยังมีขนาดเกิน 25MB';

  @override
  String get transcriptionErrorAudioNotFound =>
      'ไม่พบไฟล์เสียงที่อัปโหลด โปรดลองอีกครั้ง.';

  @override
  String get transcriptionErrorAudioExpired =>
      'ไฟล์เสียงที่อัปโหลดหมดอายุแล้ว โปรดลองอีกครั้ง.';

  @override
  String get transcriptionErrorRequestInvalid =>
      'คำขอถอดเสียงไม่ถูกต้อง โปรดอัปเดตแอปแล้วลองอีกครั้ง.';

  @override
  String get transcriptionErrorApiDeprecated =>
      'ไม่รองรับแอปเวอร์ชันนี้อีกแล้ว โปรดอัปเดตแอป';

  @override
  String get transcriptionEmptyResult => 'ไม่พบเสียงพูด';

  @override
  String get transcriptionEmptyResultHint =>
      'ไฟล์เสียงอาจมีเสียงรบกวนพื้นหลังมากเกินไป.';

  @override
  String transcriptionErrorFileTooLarge(int maxMb) {
    return 'ไฟล์ใหญ่เกินไป (สูงสุด ${maxMb}MB)';
  }

  @override
  String transcriptionErrorTooLong(int maxMin) {
    return 'เสียงยาวเกินไป (สูงสุด $maxMin นาที)';
  }

  @override
  String get deleteSubtitleConfirm => 'คุณแน่ใจหรือไม่ว่าต้องการลบคำบรรยาย?';

  @override
  String get deleteSubtitleWarning =>
      'การลบคำบรรยายจะล้างประโยคที่บันทึกไว้และความคืบหน้าการเรียนของเสียงนี้ทั้งหมดด้วย';

  @override
  String get languageAutoDetect => 'ตรวจจับอัตโนมัติ';

  @override
  String get mixedLanguageNotSupported => 'ยังไม่รองรับเสียงที่มีหลายภาษา';

  @override
  String get selectLanguage => 'เลือกภาษา';

  @override
  String get autoMergeShortSentences => 'รวมประโยคสั้นอัตโนมัติ';

  @override
  String get autoMergeShortSentencesHint =>
      'ตั้งเป้าที่ 4-7 วินาที; ปิดเพื่อคงประโยคให้สั้นลง';

  @override
  String get overwriteExistingSubtitle => 'เขียนทับคำบรรยายที่มีอยู่หรือไม่?';

  @override
  String get overwriteExistingSubtitleMessage =>
      'การดำเนินการนี้จะแทนที่คำบรรยายปัจจุบัน ดำเนินการต่อหรือไม่?';

  @override
  String get overwrite => 'เขียนทับ';

  @override
  String get downloadPodcastSubtitle => 'ดาวน์โหลดคำบรรยายพอดแคสต์';

  @override
  String get downloadPodcastSubtitleSubtitle =>
      'มีให้โดยพอดแคสต์ ไม่ต้องถอดเสียง';

  @override
  String get podcastTranscriptReminderTitle => 'คำบรรยายพอดแคสต์อาจไม่ถูกต้อง';

  @override
  String get podcastTranscriptReminderMessage =>
      'คำบรรยายที่พอดแคสต์จัดให้มีคุณภาพแตกต่างกันและอาจไม่ตรงกับเสียง หากไม่ถูกต้อง คุณสามารถใช้การถอดเสียงบนคลาวด์เพื่อสร้างคำบรรยายแทนได้.';

  @override
  String get podcastTranscriptReminderConfirm => 'เข้าใจแล้ว';

  @override
  String get downloadSubtitle => 'ดาวน์โหลดคำบรรยาย';

  @override
  String get downloadSubtitleFailed => 'ดาวน์โหลดคำบรรยายไม่สำเร็จ';

  @override
  String get audioContentEmptyWarning => 'อาจว่างเปล่า';

  @override
  String get audioContentDamagedWarning => 'เสียงมีปัญหา';

  @override
  String get audioContentSilentWarning => 'อาจไม่มีเสียง';

  @override
  String get transcriptionDamagedConfirmTitle => 'ไฟล์เสียงอาจเสียหาย';

  @override
  String get transcriptionDamagedConfirmMessage =>
      'ไฟล์เสียงนี้อาจเสียหายหรืออยู่ในรูปแบบที่ไม่รองรับ ต้องการถอดเสียงต่อไปหรือไม่?';

  @override
  String get transcriptionSilentConfirmTitle => 'ไฟล์เสียงอาจว่างเปล่า';

  @override
  String get transcriptionSilentConfirmMessage =>
      'ไฟล์เสียงนี้ดูเหมือนจะไม่มีเสียงพูด ต้องการถอดเสียงต่อไปหรือไม่?';

  @override
  String get transcriptionSilentConfirmProceed => 'ถอดเสียงต่อไป';

  @override
  String transcriptionAudioFileSize(Object size) {
    return 'ขนาดไฟล์: $size';
  }

  @override
  String transcriptionAudioDuration(Object duration) {
    return 'ความยาว: $duration';
  }

  @override
  String get transcriptionAudioUnknown => 'ตรวจไม่พบ';

  @override
  String get selectCollection => 'คอลเลกชัน (ไม่บังคับ)';

  @override
  String get noCollection => 'ไม่มี';

  @override
  String get addSubtitle => 'เพิ่มคำบรรยาย';

  @override
  String get retryTranscription => 'ลองอีกครั้ง';

  @override
  String studyTimeMinutes(int minutes) {
    return '$minutes นาที';
  }

  @override
  String studyTimeHoursMinutes(int hours, int minutes) {
    return '$hours ชม. $minutes น.';
  }

  @override
  String get studyTasks => 'งานเรียน';

  @override
  String get startButton => 'เริ่ม';

  @override
  String get continueButton => 'ดำเนินการต่อ';

  @override
  String streakDays(int count) {
    return 'ต่อเนื่อง $count วัน';
  }

  @override
  String get studyLookupEntry => 'Lookup';

  @override
  String get todayStudyTimeShort => 'วันนี้';

  @override
  String get weekStudyTimeShort => 'สัปดาห์นี้';

  @override
  String readyToReview(int count) {
    return 'พร้อมทบทวน ($count)';
  }

  @override
  String upcomingReviews(int count) {
    return 'การทบทวนที่กำลังจะมาถึง ($count)';
  }

  @override
  String get recommendedForYou => 'แนะนำสำหรับคุณ';

  @override
  String completedSection(int count) {
    return 'เนื้อหาที่เสร็จแล้ว ($count)';
  }

  @override
  String get noStudyTasks => 'ยังไม่มีงานฝึก';

  @override
  String get noStudyTasksHint => 'นำเข้าไฟล์เสียงเพื่อเริ่มฝึก';

  @override
  String get goToLibrary => 'ไปที่คลัง';

  @override
  String get allDoneTitle => 'เสร็จหมดแล้วสำหรับตอนนี้!';

  @override
  String get allDoneHint => 'เยี่ยมมาก! กลับมาทบทวนภายหลัง';

  @override
  String overdueDays(int count) {
    return 'เลยกำหนด $count วัน';
  }

  @override
  String overdueHours(int count) {
    return 'เลยกำหนด $count ชม.';
  }

  @override
  String get reviewDue => 'ถึงกำหนดทบทวน';

  @override
  String availableInDays(int count) {
    return 'อีก $count วัน';
  }

  @override
  String availableInHours(int count) {
    return 'อีก $count ชม.';
  }

  @override
  String subStageLabelFirstLearn(String subStage) {
    return 'รอบแรก - $subStage';
  }

  @override
  String subStageLabelReview(String reviewName, String subStage) {
    return '$reviewName - $subStage';
  }

  @override
  String get favoritesSentences => 'ประโยค';

  @override
  String get favoritesVocabulary => 'คำศัพท์';

  @override
  String get favoritesNoSentences => 'ยังไม่มีประโยคที่บันทึกไว้';

  @override
  String get favoritesNoSentencesHint =>
      'บุ๊กมาร์กประโยคที่ท้าทายขณะฟังทีละประโยคหรือฟังซ้ำ';

  @override
  String get favoritesNoVocabulary => 'ยังไม่มีคำศัพท์ที่บันทึกไว้';

  @override
  String get favoritesNoVocabularyHint => 'แตะคำเพื่อค้นหาและบันทึก';

  @override
  String favoritesBookmarkCount(int count) {
    return '$count ประโยค';
  }

  @override
  String get undo => 'เลิกทำ';

  @override
  String get favoritesSaveVocabulary => 'บันทึก';

  @override
  String get favoritesUnsaveVocabulary => 'เลิกบันทึก';

  @override
  String get favoritesAiLookup => 'AI';

  @override
  String get bookmarkReviewTitle => 'ทบทวนประโยคที่บันทึกไว้';

  @override
  String get bookmarkReviewStart => 'เริ่มทบทวน';

  @override
  String bookmarkReviewDueCount(int count) {
    return '$count รายการถึงกำหนดทบทวน';
  }

  @override
  String get bookmarkReviewNothingToReview => 'เสร็จหมดแล้ว!';

  @override
  String favoriteVocabularyReviewDueCount(int count) {
    return '$count รายการถึงกำหนดทบทวน';
  }

  @override
  String get favoriteReviewNothingToReview => 'เสร็จหมดแล้ว!';

  @override
  String get bookmarkReviewComplete => 'ทบทวนเสร็จแล้ว';

  @override
  String get bookmarkReviewAudioSkipped => 'ไม่มีเสียง ข้ามประโยคนี้';

  @override
  String bookmarkReviewFromAudio(String name) {
    return 'จาก: $name';
  }

  @override
  String get favoriteSourceMaterialNotFound => 'ไม่พบสื่อต้นทาง';

  @override
  String get bookmarkReviewUnsave => 'เลิกบันทึก';

  @override
  String get bookmarkReviewTapReplay => 'ฟังและระลึก';

  @override
  String get bookmarkReviewLoadingAudio => 'กำลังโหลดเสียง…';

  @override
  String get bookmarkReviewPlaying => 'กำลังเล่น';

  @override
  String get bookmarkReviewPlayOriginal => 'ฟังอีกครั้ง';

  @override
  String get bookmarkReviewTapRetry => 'แตะเพื่อลองใหม่';

  @override
  String get bookmarkReviewListenPrompt => 'แตะเพื่อเล่นซ้ำตั้งแต่ต้น';

  @override
  String get bookmarkReviewReadyTitle => 'พลิกเมื่อพร้อม';

  @override
  String get bookmarkReviewCompleted => 'เสร็จหมดแล้ว!';

  @override
  String get bookmarkReviewUnsaveFailed =>
      'ไม่สามารถเลิกบันทึกประโยคนี้ได้ โปรดลองอีกครั้ง';

  @override
  String get bookmarkReviewSettingsTitle => 'การตั้งค่าการทบทวน';

  @override
  String get bookmarkReviewShowVideo => 'Show video';

  @override
  String get bookmarkReviewShowNextReviewTime => 'แสดงเวลาทบทวนครั้งถัดไป';

  @override
  String get favoriteReviewAutoPlayFront => 'เล่นด้านหน้าอัตโนมัติ';

  @override
  String get favoriteReviewAutoPlayBack => 'เล่นด้านหลังอัตโนมัติ';

  @override
  String get favoriteReviewShowVocabularyOnFront => 'แสดงคำศัพท์ด้านหน้า';

  @override
  String get favoriteReviewShowWordDefinitionOnFront =>
      'Show definition on front';

  @override
  String get favoriteReviewShowWordDefinitionOnFrontHint => 'Words only';

  @override
  String get favoriteReviewSentenceSettings => 'การทบทวนประโยคที่บันทึกไว้';

  @override
  String get favoriteReviewVocabularySettings => 'การทบทวนคำศัพท์ที่บันทึกไว้';

  @override
  String get bookmarkReviewOrder => 'ลำดับการทบทวน';

  @override
  String get bookmarkReviewOrderSmart => 'อัตโนมัติ';

  @override
  String get bookmarkReviewOrderDueAt => 'ถึงกำหนดเร็วสุดก่อน';

  @override
  String get bookmarkReviewOrderRandom => 'สุ่ม';

  @override
  String get bookmarkReviewRatingAgain => 'จำไม่ได้';

  @override
  String get bookmarkReviewRatingGood => 'จำได้';

  @override
  String get favoriteVocabularyReviewTitle => 'ทบทวนคำศัพท์ที่บันทึกไว้';

  @override
  String get favoriteVocabularyReviewCompleted => 'เสร็จหมดแล้ว!';

  @override
  String get favoriteVocabularyReviewTapReplay => 'แตะเพื่อเล่นซ้ำ';

  @override
  String get favoriteVocabularyReviewLoadingAudio => 'กำลังโหลดเสียง…';

  @override
  String get favoriteVocabularyReviewPlaying => 'กำลังเล่น';

  @override
  String get favoriteVocabularyReviewTapRetry => 'แตะเพื่อลองใหม่';

  @override
  String get favoriteVocabularyReviewAudioSkipped =>
      'ไม่มีเสียง แตะเพื่อลองใหม่';

  @override
  String get favoriteVocabularyReviewReadyTitle => 'พลิกเมื่อพร้อม';

  @override
  String get bookmarkReviewRatingEasy => 'ง่าย';

  @override
  String get difficultPracticeSettings => 'การตั้งค่าการฝึก';

  @override
  String get difficultPracticeSettingsHint =>
      'การตั้งค่ามีผลกับเซสชันนี้เท่านั้น';

  @override
  String get difficultPracticeBlindListenRepeat =>
      'จำนวนครั้งที่ฟังโดยไม่มีคำบรรยาย';

  @override
  String get difficultPracticeShadowReadingRepeat =>
      'จำนวนครั้งที่ฟังและพูดตาม';

  @override
  String get inputWordsShort => 'อินพุต';

  @override
  String get outputWordsShort => 'เอาต์พุต';

  @override
  String listenTimeWords(String time, String words) {
    return 'ฟัง: $time · $words';
  }

  @override
  String speakTimeWords(String time, String words) {
    return 'พูด: $time · $words';
  }

  @override
  String get learnedWordFormsShort => 'คำศัพท์';

  @override
  String get learnedWordsEmptyHint =>
      'ยังไม่มีคำที่เรียนรู้ กรุณาฟังให้จบหนึ่งรอบก่อน';

  @override
  String get learnedWordsSortTimeAsc => 'เก่าสุดที่เรียนรู้';

  @override
  String get learnedWordsSortTimeDesc => 'เรียนรู้ล่าสุด';

  @override
  String get flashcardComplete => 'ทบทวนเสร็จสิ้น';

  @override
  String get flashcardSortAlphaAsc => 'A → Z';

  @override
  String get flashcardSortAlphaDesc => 'Z → A';

  @override
  String get freePlay => 'ฟังในแบบของคุณ';

  @override
  String get wordAiAnalysis => 'วิเคราะห์ด้วย AI';

  @override
  String get wordAiContextMeaning => 'ความหมายตามบริบท';

  @override
  String get wordAiCollocations => 'คำที่มักใช้คู่กัน';

  @override
  String get wordAiUsage => 'หมายเหตุการใช้งาน';

  @override
  String get wordAiWordFamily => 'ตระกูลคำ';

  @override
  String get storage => 'อื่นๆ';

  @override
  String get clearCache => 'ล้างแคช';

  @override
  String get clearCacheConfirm =>
      'การล้างแคชชั่วคราวจะช่วยเพิ่มพื้นที่ว่าง บันทึกการเรียนรู้และรายการโปรดของคุณจะไม่ได้รับผลกระทบ และข้อมูลจะถูกสร้างใหม่เมื่อจำเป็น ดำเนินการต่อหรือไม่?';

  @override
  String get clearCacheSuccess => 'ล้างแคชแล้ว';

  @override
  String clearCacheSuccessWithSize(String size) {
    return 'ล้างแคชแล้ว คืนพื้นที่ $size';
  }

  @override
  String get clearCacheEmpty => 'แคชว่างอยู่แล้ว';

  @override
  String get confirm => 'ยืนยัน';

  @override
  String get autoCompletedNoDifficultReview => 'บันทึก 0 ประโยค, ข้ามแล้ว';

  @override
  String get termsOfService => 'ข้อกำหนดการให้บริการ';

  @override
  String get privacyPolicy => 'นโยบายความเป็นส่วนตัว';

  @override
  String get writeFeedback => 'เขียนข้อเสนอแนะ';

  @override
  String get rateUs => 'ให้คะแนนเรา';

  @override
  String get joinCommunity => 'เข้าร่วมชุมชน';

  @override
  String get aboutCommunity => 'เข้าร่วมชุมชน';

  @override
  String get joinCommunityInviteSubtitle => 'เรียนรู้ ถาม และแบ่งปัน';

  @override
  String get viewSourceCode => 'โปรเจกต์โอเพนซอร์ส';

  @override
  String updateAvailable(String version) {
    return 'มีเวอร์ชันใหม่ v$version';
  }

  @override
  String get updateNow => 'อัปเดตตอนนี้';

  @override
  String get updateLater => 'ภายหลัง';

  @override
  String get forceUpdateTitle => 'ต้องอัปเดต';

  @override
  String get forceUpdateMessage =>
      'เวอร์ชันปัจจุบันไม่รองรับแล้ว โปรดอัปเดตเพื่อใช้งานต่อ';

  @override
  String get releaseNotesTitle => 'มีอะไรใหม่';

  @override
  String get copyDownloadLink => 'คัดลอกลิงก์ดาวน์โหลด';

  @override
  String get linkCopied => 'คัดลอกลิงก์แล้ว';

  @override
  String get checkForUpdate => 'ตรวจสอบอัปเดต';

  @override
  String get alreadyLatest => 'เป็นเวอร์ชันล่าสุดแล้ว';

  @override
  String get checkUpdateFailed => 'ตรวจสอบไม่สำเร็จ โปรดตรวจสอบเครือข่าย';

  @override
  String get demoMode => 'โหมดสาธิต';

  @override
  String get practiceRemoveMark => 'ยกเลิกการทำเครื่องหมาย';

  @override
  String get practiceAddMark => 'ทำเครื่องหมายอีกครั้ง';

  @override
  String get blindListenListeningHint => 'ฟังให้ดี...';

  @override
  String get blindListenPreListenHint => 'ฟังก่อน แล้วจึงนึกทบทวน';

  @override
  String get blindListenSettingsTitle => 'ตั้งค่าการฟัง';

  @override
  String get blindListenPauseBetween => 'หยุดพักระหว่างช่วง';

  @override
  String get blindListenTargetDuration => 'ความยาวช่วง';

  @override
  String get blindListenDisplayHideAll => 'ซ่อนคำบรรยาย';

  @override
  String get blindListenRecallHint => 'นึกทบทวนสิ่งที่เพิ่งฟัง';

  @override
  String get blindListenControlModeAutoDesc =>
      'เล่นซ้ำอัตโนมัติ หยุดอัตโนมัติ ไปต่ออัตโนมัติ';

  @override
  String get blindListenControlModeManualDesc =>
      'แตะเพื่อเล่นซ้ำ แตะเพื่อไปต่อ';

  @override
  String get blindListenNoParagraph => 'ไม่ได้แบ่งช่วง';

  @override
  String blindListenParagraphCount(int count) {
    return '$count ช่วง';
  }

  @override
  String get resetLearningProgress => 'รีเซ็ตความคืบหน้า';

  @override
  String get resetLearningProgressConfirmTitle =>
      'รีเซ็ตความคืบหน้าการเรียนหรือไม่?';

  @override
  String resetLearningProgressConfirmMessage(String name) {
    return 'การดำเนินการนี้จะล้างความคืบหน้าการเรียนทั้งหมดสำหรับ \"$name\" และไม่สามารถย้อนกลับได้';
  }

  @override
  String get resetLearningProgressDone => 'รีเซ็ตความคืบหน้าการเรียนแล้ว';

  @override
  String get pauseLearning => 'หยุดชั่วคราว';

  @override
  String get resumeLearning => 'เรียนต่อ';

  @override
  String get pausedChipLabel => 'หยุดชั่วคราว';

  @override
  String get pauseLearningConfirmTitle => 'หยุดการเรียนชั่วคราวหรือไม่?';

  @override
  String get pauseLearningConfirmMessage =>
      'ระบบจะหยุดกำหนดการทบทวนสำหรับเสียงนี้ คุณสามารถเรียนต่อได้ทุกเมื่อ';

  @override
  String reviewReminderBody(String audioName, int round) {
    return '$audioName · รอบทบทวนที่ $round พร้อมแล้ว';
  }

  @override
  String get reviewReminderSavedBody1 => 'ถึงเวลาทบทวนประโยคและคำที่บันทึกไว้';

  @override
  String get reviewReminderSavedBody2 =>
      'ฟังประโยคที่บันทึกไว้อีกครั้งเพื่อจดจำให้แม่น';

  @override
  String get reviewReminderSavedBody3 =>
      'ใช้เวลาว่างฟังสักสองสามประโยคก็ช่วยได้';

  @override
  String get reviewReminderSavedBody4 => 'ประโยคที่บันทึกไว้กำลังรอคุณอยู่';

  @override
  String get reviewReminderSavedBody5 =>
      'การทำซ้ำคือสิ่งที่ทำให้จำได้ มาเริ่มทบทวนกัน';

  @override
  String get reviewReminderSavedBody6 =>
      'ฟังอีกสักสองสามครั้ง ประโยคที่บันทึกไว้จะเป็นของคุณ';

  @override
  String get reviewReminderSavedBody7 =>
      'การทบทวนแบบเว้นช่วงคือกุญแจของการจำ มาเริ่มสักรอบ';

  @override
  String get reviewReminderSavedBody8 =>
      'ฟังประโยคที่คุ้นเคยอีกครั้งแล้วคุณจะสังเกตเห็นสิ่งใหม่';

  @override
  String get reviewReminderSavedBody9 =>
      'รายการที่บันทึกไว้ต้องได้รับการทบทวน ไม่อย่างนั้นจะเลือนหาย';

  @override
  String get reviewReminderSavedBody10 =>
      'การฟังสร้างผลลัพธ์เมื่อเวลาผ่านไป ทบทวนประโยคที่บันทึกไว้';

  @override
  String get stageBlindListen => 'ฟังโดยไม่ดูคำบรรยาย';

  @override
  String get stageIntensiveListen => 'ฟังทีละประโยค';

  @override
  String get stageListenAndRepeat => 'ฟังและพูดตาม';

  @override
  String get stageRetell => 'ฟังและเล่าใหม่';

  @override
  String get stageReviewDifficultPractice => 'ฝึกประโยคที่บันทึกไว้';

  @override
  String get stageBookmarkReview => 'ทบทวนประโยค';

  @override
  String get stageFlashcard => 'ทบทวนคำศัพท์';

  @override
  String stageBreakdownTitle(String date) {
    return '$date';
  }

  @override
  String get stageBreakdownToday => ' (วันนี้)';

  @override
  String get stageBreakdownTotal => 'รวม';

  @override
  String get stageBreakdownLessThanOneMin => '<1 นาที';

  @override
  String get stageBreakdownListenShort => 'ฟัง';

  @override
  String get stageBreakdownSpeakShort => 'พูด';

  @override
  String get todayNewWordsShort => 'คำใหม่';

  @override
  String get stageBreakdownNoStageData =>
      'ข้อมูลรายละเอียดจะเริ่มบันทึกตั้งแต่เวอร์ชันนี้';

  @override
  String get stageBreakdownNoRecord => 'ไม่มีบันทึกการเรียนในวันนี้';

  @override
  String get chartLegendListening => 'การฟัง';

  @override
  String get chartLegendSpeaking => 'การพูด';

  @override
  String get chartLegendOther => 'อื่น ๆ';

  @override
  String get chartLegendOtherHint => 'การคิด การหยุดพัก ฯลฯ';

  @override
  String get reminderSettings => 'แจ้งเตือนการทบทวน';

  @override
  String get savedReviewReminderSection =>
      'การแจ้งเตือนทบทวน ‘รายการที่บันทึกไว้’';

  @override
  String get savedReviewReminderToggle => 'แจ้งเตือนเนื้อหาที่บันทึกไว้';

  @override
  String get savedReviewReminderTime => 'เวลาการแจ้งเตือนรายวัน';

  @override
  String get savedReviewReminderDescription =>
      'ทบทวนเนื้อหาที่บันทึกไว้ระหว่างเดินทางหรือก่อนนอนเพื่อผลลัพธ์ที่ดีที่สุด';

  @override
  String get audioReviewReminderSection => 'การแจ้งเตือนทบทวนเสียง';

  @override
  String get audioReviewReminderToggle => 'แจ้งเตือนเสียงที่ถึงกำหนด';

  @override
  String get audioReviewReminderDescription =>
      'รับการแจ้งเตือนเมื่อถึงเวลาทบทวน ช่วยให้คุณไม่หลุดกำหนด';

  @override
  String get notificationPromptTitle => 'จดจำสิ่งที่เรียนไว้ให้แม่น';

  @override
  String get notificationPromptBody =>
      'ความจำจะติดแน่นเมื่อทบทวนในจังหวะที่เหมาะสม เราจะเตือนเฉพาะเมื่อจำเป็น';

  @override
  String get notificationPromptTitleLearning => 'ทบทวนขณะยังสดใหม่';

  @override
  String get notificationPromptBodyLearning =>
      'เปิดการแจ้งเตือน เราจะเตือนในเวลาที่เหมาะสมเพื่อเสริมสิ่งที่เพิ่งเรียน';

  @override
  String get notificationPromptTitleBookmark => 'อย่าลืมรายการที่บันทึกไว้';

  @override
  String get notificationPromptBodyBookmark =>
      'เปิดการแจ้งเตือนเพื่อทบทวนเนื้อหาที่บันทึกไว้ตามตารางเวลาปกติ';

  @override
  String get notificationPromptCtaGrant => 'เปิดการแจ้งเตือน';

  @override
  String get notificationPromptCtaDismiss => 'ไว้ทีหลัง';

  @override
  String get notificationDisabledBanner =>
      'การแจ้งเตือนปิดอยู่ คุณจะไม่ได้รับการแจ้งเตือนให้ทบทวน';

  @override
  String get notificationDisabledBannerCta => 'เปิดการตั้งค่า';

  @override
  String get notificationNotGrantedBanner =>
      'อนุญาตการแจ้งเตือนเพื่อรับการแจ้งเตือนทบทวนรายวัน';

  @override
  String get notificationNotGrantedBannerCta => 'เปิดใช้งาน';

  @override
  String recentCompletions(int count) {
    return 'งานที่เพิ่งเสร็จสิ้น ($count)';
  }

  @override
  String get timeAgoJustNow => 'เมื่อสักครู่';

  @override
  String timeAgoMinutes(int minutes) {
    return '$minutes นาทีที่แล้ว';
  }

  @override
  String timeAgoHours(int hours) {
    return '$hours ชั่วโมงที่แล้ว';
  }

  @override
  String timeFromNowSeconds(int seconds) {
    return 'ในอีก $seconds วินาที';
  }

  @override
  String get exportAudio => 'ส่งออกเสียง';

  @override
  String get exportAudioFile => 'เสียง';

  @override
  String get exportVideo => 'ส่งออกวิดีโอ';

  @override
  String get exportVideoFile => 'วิดีโอ';

  @override
  String get exportSubtitleFile => 'คำบรรยาย';

  @override
  String get exportSelectFiles => 'เลือกไฟล์ที่จะส่งออก';

  @override
  String get exportPdf => 'ส่งออก PDF';

  @override
  String get pdfExporting => 'กำลังสร้าง PDF…';

  @override
  String pdfExportFailed(String error) {
    return 'ส่งออก PDF ไม่สำเร็จ: $error';
  }

  @override
  String pdfMetaDuration(String duration) {
    return 'ระยะเวลา $duration';
  }

  @override
  String pdfMetaSentences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ประโยค',
      one: '1 ประโยค',
    );
    return '$_temp0';
  }

  @override
  String pdfMetaWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count คำ',
      one: '1 คำ',
    );
    return '$_temp0';
  }

  @override
  String get pdfAppendixTitle => 'ภาคผนวก · การวิเคราะห์ประโยค';

  @override
  String get pdfPreviewTitle => 'ตัวอย่างก่อนส่งออก';

  @override
  String get pdfShare => 'แชร์';

  @override
  String get pdfOptionTranslation => 'คำแปลของประโยคที่บันทึกไว้';

  @override
  String get pdfOptionVocab => 'ความหมายของคำที่บันทึกไว้';

  @override
  String get pdfOptionAnalysis => 'การวิเคราะห์ประโยคสำคัญ';

  @override
  String get pdfExportReminderTitle => 'PDF คือบันทึกทบทวนของคุณ';

  @override
  String get pdfExportReminderMessage =>
      'เราแนะนำให้ส่งออก PDF หลังจากเรียนจบรอบแรก\n\nการฟังทีละประโยค การฟังซ้ำ และการฟังโดยไม่มีคำบรรยายช่วยให้คุณเชี่ยวชาญสิ่งที่ได้ยิน และ PDF จะรวบรวมคำแปลและการวิเคราะห์ของประโยคที่บันทึกไว้ รวมถึงคำที่บันทึกไว้สำหรับการทบทวนในภายหลัง';

  @override
  String get pdfExportReminderConfirm => 'เข้าใจแล้ว';

  @override
  String get exportData => 'ส่งออกข้อมูล';

  @override
  String get importing => 'กำลังนำเข้า...';

  @override
  String get exportSuccess => 'ส่งออกเสร็จสิ้น';

  @override
  String get downloadSuccess => 'ดาวน์โหลดเสร็จสิ้น';

  @override
  String get importSuccess => 'นำเข้าเสร็จสิ้น';

  @override
  String get backupTime => 'เวลาสำรองข้อมูล';

  @override
  String get backupVersion => 'เวอร์ชันแอป';

  @override
  String get backupFileCount => 'ไฟล์มีเดีย';

  @override
  String get backupSize => 'ขนาดรวม';

  @override
  String get importIncompatible =>
      'ข้อมูลสำรองนี้สร้างจากแอปเวอร์ชันใหม่กว่า กรุณาอัปเดตแอปก่อน';

  @override
  String get importInvalidFile => 'ไฟล์สำรองข้อมูลไม่ถูกต้อง';

  @override
  String get exportingDatabase => 'กำลังส่งออกฐานข้อมูล...';

  @override
  String get exportingPreferences => 'กำลังส่งออกการตั้งค่า...';

  @override
  String get exportingMedia => 'กำลังส่งออกไฟล์มีเดีย...';

  @override
  String get exportingPacking => 'กำลังแพ็กไฟล์สำรองข้อมูล...';

  @override
  String get importingExtracting => 'กำลังแตกไฟล์สำรองข้อมูล...';

  @override
  String get importingMedia => 'กำลังกู้คืนไฟล์มีเดีย...';

  @override
  String get importingDatabase => 'กำลังกู้คืนฐานข้อมูล...';

  @override
  String get importingPreferences => 'กำลังกู้คืนการตั้งค่า...';

  @override
  String get backupAndRestore => 'สำรองและกู้คืนข้อมูล';

  @override
  String get backupData => 'สำรองข้อมูล';

  @override
  String get restoreData => 'กู้คืน';

  @override
  String get backupReadyTitle => 'ไฟล์สำรองข้อมูลพร้อมแล้ว';

  @override
  String get backupFileName => 'ชื่อไฟล์';

  @override
  String get restoreOverwriteTitle => 'เขียนทับและกู้คืนข้อมูลทั้งหมด?';

  @override
  String get restoreOverwriteMessage =>
      'การดำเนินการนี้จะเขียนทับข้อมูลการเรียนรู้ การตั้งค่า ไฟล์เสียง คำบรรยาย และพจนานุกรมบนอุปกรณ์นี้ ไม่สามารถยกเลิกได้';

  @override
  String get restoreOverwriteAction => 'เขียนทับและกู้คืน';

  @override
  String get exportingResources => 'กำลังสำรองพจนานุกรมออฟไลน์...';

  @override
  String get importingResources => 'กำลังกู้คืนพจนานุกรมออฟไลน์...';

  @override
  String backupFailed(String error) {
    return 'การสำรองข้อมูลล้มเหลว: $error';
  }

  @override
  String restoreFailed(String error) {
    return 'การกู้คืนล้มเหลว: $error';
  }

  @override
  String get activityCalendar => 'ปฏิทินกิจกรรม';

  @override
  String get studyDurationNoRecords => 'ไม่มีบันทึกการเรียน';

  @override
  String monthlySummaryTitle(String month) {
    return 'สถิติ$month';
  }

  @override
  String get unitMinute => 'นาที';

  @override
  String get unitHour => 'ชม.';

  @override
  String get unitDay => 'วัน';

  @override
  String hourMinuteUnit(int minutes) {
    return 'ชม. $minutes น.';
  }

  @override
  String get unitSecond => 'วิ';

  @override
  String get unitItem => 'รายการ';

  @override
  String get monthlyTotal => 'รวม';

  @override
  String get monthlyActiveDays => 'วันที่ใช้งาน';

  @override
  String get monthlyAvgPerDay => 'เฉลี่ย/วัน';

  @override
  String get monthlyBestStreak => 'สถิติต่อเนื่องสูงสุด';

  @override
  String get senseGroupSplit => 'แบ่งเป็นกลุ่มความหมาย';

  @override
  String get senseGroupLoading => 'กำลังแบ่ง...';

  @override
  String get senseGroupSingleGroup => 'ประโยคนี้เป็นกลุ่มความหมายเดียว';

  @override
  String get senseGroupSave => 'บันทึก';

  @override
  String get senseGroupSaved => 'บันทึกแล้ว';

  @override
  String get annotationBtnSenseGroup => 'กลุ่มความหมาย';

  @override
  String get annotationBtnSenseGroupMedium => 'กลุ่มที่ใหญ่ขึ้น';

  @override
  String get annotationBtnSenseGroupFine => 'กลุ่มที่เล็กลง';

  @override
  String get annotationBtnTranslation => 'คำแปล';

  @override
  String get annotationBtnAnalysis => 'วิเคราะห์';

  @override
  String get senseGroupLoadFailed =>
      'แบ่งกลุ่มความหมายไม่สำเร็จ โปรดลองอีกครั้ง';

  @override
  String get senseGroupSignInRequiredTitle => 'ลงชื่อเข้าใช้เพื่อใช้ฟีเจอร์ AI';

  @override
  String get senseGroupSignInRequiredMessage =>
      'โปรดลงชื่อเข้าใช้ก่อนใช้ฟีเจอร์ AI';

  @override
  String get senseGroupSyntheticTimingNoticeTitle => 'เวลาอาจไม่แม่นยำ';

  @override
  String get senseGroupSyntheticTimingNoticeMessage =>
      'เวลาการเล่นกลุ่มความหมายนี้อ้างอิงจากซับไตเติลที่คุณอัปโหลดและอาจไม่แม่นยำ';

  @override
  String get transcriptionSignInRequiredTitle =>
      'ลงชื่อเข้าใช้เพื่อใช้การถอดเสียงด้วย AI';

  @override
  String get transcriptionSignInRequiredMessage =>
      'การถอดเสียงด้วย AI ใช้บริการถอดเสียงบนคลาวด์ ลงชื่อเข้าใช้เพื่อถอดเสียงด้วย AI';

  @override
  String get senseGroupNotAvailable => 'ยังเล่นกลุ่มความหมายของเสียงนี้ไม่ได้';

  @override
  String get wordTimestampsNotFound =>
      'ไม่พบเวลาของแต่ละคำ โปรดรีสตาร์ตแอปเพื่อลองอีกครั้ง';

  @override
  String get recycleBinTitle => 'ถังขยะ';

  @override
  String get reviewStatisticsTitle => 'สถิติการทบทวน';

  @override
  String get reviewStatisticsAll => 'ทั้งหมด';

  @override
  String get reviewStatisticsSentences => 'ประโยค';

  @override
  String get reviewStatisticsVocabulary => 'คำศัพท์';

  @override
  String get reviewStatisticsTodayOverview => 'ภาพรวมวันนี้';

  @override
  String get reviewStatisticsTodayCompleted => 'เสร็จสิ้นวันนี้';

  @override
  String get reviewCompletionReviewed => 'ทบทวนแล้ว';

  @override
  String get reviewStatusRemaining => 'คงเหลือ';

  @override
  String get reviewStatisticsDuration => 'เวลาทบทวน';

  @override
  String reviewStatisticsCurrentDue(String count) {
    return '$count รายการพร้อมทบทวน';
  }

  @override
  String reviewStatisticsCurrentDueBreakdown(Object overdue, Object today) {
    return 'เลยกำหนด $overdue, ครบกำหนดวันนี้ $today';
  }

  @override
  String get reviewStatisticsStreak => 'ทบทวนต่อเนื่อง';

  @override
  String reviewStatisticsStreakExplanation(int count) {
    return 'ทบทวนต่อเนื่อง $count วัน';
  }

  @override
  String get reviewStatisticsLearningRhythm => 'จังหวะการเรียนรู้';

  @override
  String get reviewStatisticsTrend => '30 วันที่ผ่านมา';

  @override
  String get reviewStatisticsTrendExplanation =>
      'รายการที่บันทึกไว้และทบทวนเสร็จในแต่ละวัน (ไม่ซ้ำ)';

  @override
  String get reviewStatisticsReviewPlan => 'แผนทบทวน';

  @override
  String get reviewStatisticsUpcoming => '7 วันข้างหน้า รวมวันนี้';

  @override
  String get reviewStatisticsUpcomingExplanation =>
      'รายการที่บันทึกไว้ซึ่งครบกำหนดในแต่ละวัน';

  @override
  String get reviewStatisticsTodayShort => 'วันนี้';

  @override
  String get reviewStatisticsRecentPerformance => 'ผลลัพธ์ล่าสุด';

  @override
  String get reviewStatisticsRatings => 'อัตราการจดจำ 30 วัน';

  @override
  String get reviewStatisticsRetentionRate => 'การจดจำ';

  @override
  String get reviewStatisticsRetentionExplanation =>
      'อิงจากการทบทวนครั้งแรกของแต่ละรายการใน 30 วันที่ผ่านมา\nอัตราการจดจำ = (จำได้ + ง่าย) / ทั้งหมด';

  @override
  String get reviewStatisticsEmptyRatings => 'ยังไม่มีการให้คะแนน';

  @override
  String get reviewStatisticsContent => 'เนื้อหาที่ทบทวน';

  @override
  String get reviewStatisticsContentExplanation =>
      'ทบทวนเสร็จอย่างน้อยหนึ่งครั้ง';

  @override
  String get reviewStatisticsHistory => 'ประวัติ';

  @override
  String reviewStatisticsItemCount(int count) {
    return '$count รายการ';
  }

  @override
  String get reviewStatisticsLoadError => 'โหลดสถิติไม่สำเร็จ';

  @override
  String get recycleBinEmpty => 'ไม่มีรายการที่ลบ';

  @override
  String get recycleBinClearAll => 'ล้างทั้งหมด';

  @override
  String recycleBinClearAllConfirm(int count) {
    return 'ลบทั้ง $count รายการอย่างถาวรหรือไม่? การดำเนินการนี้ไม่สามารถเลิกทำได้';
  }

  @override
  String get recycleBinSortTimeDesc => 'ลบล่าสุด';

  @override
  String get recycleBinSortTimeAsc => 'ลบเก่าสุด';

  @override
  String recycleBinItemCount(int count) {
    return '$count รายการ';
  }

  @override
  String filesSelected(int count) {
    return 'เลือก $count ไฟล์';
  }

  @override
  String processingFileOf(int current, int total) {
    return 'กำลังประมวลผล $current จาก $total...';
  }

  @override
  String importingFileProgress(int current, int total, String name) {
    return 'กำลังนำเข้า $current/$total: $name';
  }

  @override
  String multipleAudioAdded(int count) {
    return 'เพิ่ม $count รายการ';
  }

  @override
  String audioImportedCount(int count) {
    return 'นำเข้า $count รายการ';
  }

  @override
  String audioImportedWithSubtitleCount(int count) {
    return '$count รายการมีซับไตเติล';
  }

  @override
  String duplicatesSkipped(int count) {
    return 'ข้ามรายการซ้ำ $count รายการ';
  }

  @override
  String importFailedCount(int count) {
    return 'ล้มเหลว $count รายการ';
  }

  @override
  String get duplicatesSkippedDetail =>
      'ไฟล์ต่อไปนี้มีเนื้อหาเหมือนกับรายการที่มีอยู่ในคอลเลกชันนี้แล้วและถูกข้าม:';

  @override
  String duplicateExistingFileName(String name) {
    return 'ชื่อไฟล์ซ้ำ: $name';
  }

  @override
  String duplicateOfExisting(String name) {
    return 'เนื้อหาเดียวกับ \"$name\"';
  }

  @override
  String get removeFile => 'นำออก';

  @override
  String get dictionaryLookupFailed =>
      'ค้นหาไม่สำเร็จ ตรวจสอบเครือข่ายแล้วลองอีกครั้ง';

  @override
  String dictionaryBaseFormHint(String lemma) {
    return 'กำลังแสดงผลสำหรับรูปพื้นฐาน “$lemma”';
  }

  @override
  String get download => 'ดาวน์โหลด';

  @override
  String get retry => 'ลองอีกครั้ง';

  @override
  String get mediaPreparingHint => 'กำลังดาวน์โหลดเสียงและคำบรรยาย…';

  @override
  String get guideNext => 'ถัดไป';

  @override
  String get guideDone => 'เสร็จสิ้น';

  @override
  String get guideSkip => 'ข้าม';

  @override
  String get guideLibraryCreateCollectionDescription =>
      'แตะที่นี่เพื่อสร้างคอลเลกชันใหม่';

  @override
  String get guideCollectionAudioMenuDescription =>
      'แตะที่นี่เพื่อจัดการคำบรรยายของเสียงนี้ คอลเลกชันที่เสียงนี้อยู่ แท็ก และอื่น ๆ';

  @override
  String get guideCollectionUploadDescription =>
      'แตะที่นี่เพื่ออัปโหลดเสียงของคุณเอง';

  @override
  String get guidePlanAddSubtitleTitle => 'เพิ่มคำบรรยาย';

  @override
  String get guidePlanAddSubtitleDescription =>
      'สร้างคำบรรยายด้วย AI ด้วยการแตะครั้งเดียว หรืออัปโหลดไฟล์คำบรรยายในเครื่อง คุณสามารถเริ่มฝึกเสียงนี้ได้ทันที';

  @override
  String get guidePlanFreePlayTitle => 'ฟังในแบบของคุณ';

  @override
  String get guidePlanFreePlayDescription =>
      'เครื่องเล่นเสียงแบบครบวงจรที่ยืดหยุ่น สำหรับฟังในแบบและจังหวะของคุณเอง';

  @override
  String get guidePlanStartLearningTitle => 'ทำตามแผนฝึกค่าเริ่มต้น';

  @override
  String get guidePlanStartLearningDescription =>
      'แตะที่นี่เพื่อทำตามแผนฝึกค่าเริ่มต้นทีละขั้น Echo Loop จะแนะนำคุณและเตือนให้ทบทวนในเวลาที่เหมาะสม';

  @override
  String get guidePlanPauseLearningTitle => 'หยุดชั่วคราว';

  @override
  String get guidePlanPauseLearningDescription =>
      'หากคุณไม่ต้องการฝึกเสียงนี้อีกต่อไป แตะที่นี่เพื่อหยุดชั่วคราวได้ทุกเมื่อ การเตือนทบทวนจะหยุดลง และคุณสามารถกลับมาฝึกต่อได้ด้วยการแตะครั้งเดียวภายหลัง';

  @override
  String get guideRetellSkipTitle => 'ข้ามการเล่าเรื่องครั้งนี้';

  @override
  String get guideRetellSkipDescription =>
      'การเล่าเรื่องช่วยสร้างทักษะการพูดภาษาอังกฤษได้เร็ว หากตอนนี้คุณอยากเน้นการฟัง แตะที่นี่เพื่อข้ามขั้นตอนนี้';

  @override
  String get learningProgressLoadFailed =>
      'โหลดความคืบหน้าการเรียนรู้ไม่สำเร็จ โปรดลองอีกครั้งภายหลัง';

  @override
  String get guideStudyStatsHeaderTitle => 'ภาพรวมวันนี้';

  @override
  String get guideStudyStatsHeaderDescription =>
      'เวลาฟัง เวลาฝึกพูด และคำศัพท์ใหม่ของคุณในวันนี้ สรุปไว้ที่นี่ทั้งหมด แตะการ์ดหรือแถบเพื่อดูรายละเอียดเพิ่มเติม';

  @override
  String get guideStudyStreakDescription =>
      'แตะที่นี่เพื่อดูปฏิทินการเรียนรู้ของคุณ';

  @override
  String get guideFavoritesSentencesListDescription =>
      'ประโยคที่คุณบันทึกไว้ จัดกลุ่มตามแหล่งที่มา';

  @override
  String get guideFavoritesVocabularyListDescription =>
      'คำ วลี และกลุ่มความหมายที่คุณบันทึกไว้';

  @override
  String get guideSentenceTileBodyDescription => 'แตะประโยคเพื่อเล่นจากจุดนี้';

  @override
  String get guideSentenceTileExplanationDescription =>
      'แตะไอคอนคำอธิบายทางซ้ายเพื่อดูคำอธิบายของประโยคนี้';

  @override
  String get viewSentenceExplanation => 'ดูคำอธิบายประโยค';

  @override
  String get guideSubtitleEditorBoundaryHandleDescription =>
      'ลากจุดจับสีแดงหรือสีเขียวบนรูปคลื่นเพื่อปรับเวลาเริ่มและสิ้นสุดของประโยคปัจจุบัน';

  @override
  String get guideSubtitleEditorSentencePlayDescription =>
      'แตะปุ่มเล่นทางซ้ายเพื่อเล่นประโยคนี้';

  @override
  String get guideSubtitleEditorSentenceMenuDescription =>
      'แตะเมนูทางขวาเพื่อรวมหรือลบประโยคนี้';

  @override
  String get guideSentenceAnnotationSentenceDescription =>
      'แตะหรือกดค้างเพื่อเลือกข้อความและค้นหาคำ';

  @override
  String get guideSentenceAnnotationSenseGroupDescription =>
      'แบ่งประโยคออกเป็นกลุ่มความหมาย เพื่อให้บรรทัดยาวและซับซ้อนติดตามได้ง่ายขึ้น';

  @override
  String get guideSentenceAnnotationAnalysisDescription =>
      'ตรวจสอบไวยากรณ์ วลีสำคัญ และเคล็ดลับการฟังสำหรับประโยคนี้';

  @override
  String get resetNewUserGuide => 'รีเซ็ตคำแนะนำผู้ใช้ใหม่';

  @override
  String get resetNewUserGuideDone => 'รีเซ็ตคำแนะนำผู้ใช้ใหม่แล้ว';

  @override
  String get resetOnboarding => 'รีเซ็ตแบบสำรวจเริ่มต้นใช้งาน';

  @override
  String get resetOnboardingDone =>
      'รีเซ็ตการเริ่มต้นใช้งานแล้ว โปรดรีสตาร์ทแอปเพื่อทำแบบสำรวจอีกครั้ง';

  @override
  String get discoverCommunityCollections => 'ค้นพบแหล่งเรียนรู้';

  @override
  String get discoverEmpty => 'ยังไม่มีคอลเลกชันที่คัดสรร';

  @override
  String get discoverLoadFailed => 'โหลดไม่สำเร็จ แตะเพื่อลองอีกครั้ง';

  @override
  String get discoverRetry => 'ลองอีกครั้ง';

  @override
  String get discoverPodcastEntryTitle => 'Apple Podcasts';

  @override
  String get discoverPodcastEmpty => 'ยังไม่มีพอดแคสต์ที่คัดสรร';

  @override
  String get podcastSignInRequiredMessage =>
      'เข้าสู่ระบบเพื่อเพิ่มพอดแคสต์ที่คัดสรรไปยังคอลเลกชันของฉัน และเรียนตอนใหม่ ๆ ต่อไป';

  @override
  String get podcastPreviewSubscribeFailed =>
      'เพิ่มไม่สำเร็จ ฟีด RSS บางรายการหรือ Apple Podcasts อาจใช้งานไม่ได้บนเครือข่ายปัจจุบัน ลองอีกครั้งภายหลังหรือสลับเครือข่าย';

  @override
  String get podcastEnrollNeededTitle => 'เพิ่มพอดแคสต์ก่อน';

  @override
  String get podcastEnrollNeededMessage =>
      'เพิ่มพอดแคสต์นี้ไปยังคอลเลกชันของฉัน แล้วคุณจะสามารถดาวน์โหลดและเรียนตอนนี้ได้';

  @override
  String get podcastPreviewNetworkFailed =>
      'ไม่สามารถดึงเนื้อหาพอดแคสต์ได้ Apple Podcasts หรือฟีด RSS บางรายการอาจใช้งานไม่ได้บนเครือข่ายปัจจุบัน ลองอีกครั้งภายหลังหรือสลับเครือข่าย';

  @override
  String get podcastPreviewAppleFailed =>
      'ไม่สามารถจดจำลิงก์ Apple Podcast ได้ เครือข่ายปัจจุบันอาจเข้าถึงบริการค้นหาพอดแคสต์ของ Apple ไม่ได้ ลองอีกครั้งภายหลังหรือสลับเครือข่าย';

  @override
  String get podcastPreviewParseFailed =>
      'ไม่รองรับรูปแบบฟีดพอดแคสต์นี้ จึงไม่สามารถอ่านรายการตอนได้';

  @override
  String get podcastFeedBlocked =>
      'แหล่งพอดแคสต์นี้กำลังบล็อกการเข้าถึงอัตโนมัติบนเครือข่ายปัจจุบัน ลองอีกครั้งภายหลังหรือสลับไปใช้เครือข่ายอื่น';

  @override
  String get podcastPreviewEmpty => 'ยังไม่พบตอน';

  @override
  String get localCollectionBadge => 'ในเครื่อง';

  @override
  String get communityBadge => 'แชร์แล้ว';

  @override
  String get communityDeprecatedBadge => 'นำออกแล้ว';

  @override
  String get podcastCollectionBadge => 'พอดแคสต์';

  @override
  String get addToMyCollections => 'เพิ่มไปยังคอลเลกชันของฉัน';

  @override
  String get communityCollectionSignInRequiredTitle =>
      'เข้าสู่ระบบเพื่อเพิ่มคอลเลกชัน';

  @override
  String get communityCollectionSignInRequiredMessage =>
      'เข้าสู่ระบบเพื่อเพิ่มคอลเลกชันที่แชร์ไปยังคอลเลกชันของฉัน และซิงก์ไฟล์ใหม่';

  @override
  String get goLearn => 'เริ่มฝึก';

  @override
  String get communityCollectionAdded => 'เพิ่มแล้ว';

  @override
  String get removeFromMyCollections => 'นำออกจากคอลเลกชันของฉัน';

  @override
  String get enrollSucceeded => 'เพิ่มไปยังคอลเลกชันของฉันแล้ว';

  @override
  String get enrollFailed =>
      'เพิ่มไม่สำเร็จ โปรดตรวจสอบเครือข่ายแล้วลองอีกครั้ง';

  @override
  String removeCommunityConfirmTitle(String name) {
    return 'นำออก \"$name\"?';
  }

  @override
  String get removeCommunityConfirmMessage =>
      'ไฟล์สื่อ คำบรรยายของไฟล์เหล่านั้น และบันทึกการเรียนรู้ทั้งหมดในคอลเลกชันนี้จะถูกลบ ไม่สามารถย้อนกลับได้';

  @override
  String get removeCommunityConfirmConfirm => 'นำออก';

  @override
  String get communityCollectionDeprecated =>
      'คอลเลกชันนี้ถูกลบแล้ว คุณยังสามารถใช้สำเนาในเครื่องได้';

  @override
  String get communityCollectionRefreshFailed =>
      'ซิงก์ไม่สำเร็จ ดึงลงเพื่อลองอีกครั้ง';

  @override
  String get communityFileUnavailable =>
      'ไฟล์นี้ถูกลบออกจากคอลเลกชันที่แชร์แล้ว';

  @override
  String communityFilesRemoved(int count) {
    return '$count ไฟล์ถูกลบออกจากคอลเลกชันที่แชร์';
  }

  @override
  String get downloadCancel => 'ยกเลิกการดาวน์โหลด';

  @override
  String downloadFailed(String name) {
    return 'ดาวน์โหลด $name ไม่สำเร็จ โปรดลองอีกครั้ง';
  }

  @override
  String get updateCommunitySubtitle => 'อัปเดตคำบรรยาย';

  @override
  String get updateCommunitySubtitleConfirm => 'อัปเดตคำบรรยายหรือไม่?';

  @override
  String get updateCommunitySubtitleWarning =>
      'การอัปเดตคำบรรยายจะแทนที่คำบรรยายในเครื่อง และล้างประโยคที่บันทึกไว้ทั้งหมดรวมถึงความคืบหน้าการเรียนรู้ของสื่อนี้';

  @override
  String get communitySubtitleUpdated => 'อัปเดตคำบรรยายแล้ว';

  @override
  String get communitySubtitleUpdateFailed =>
      'อัปเดตคำบรรยายไม่สำเร็จ โปรดลองอีกครั้ง';

  @override
  String get downloadLoading => 'กำลังโหลด';

  @override
  String get backgroundDownloadRunningTitle => 'กำลังดาวน์โหลด';

  @override
  String get backgroundDownloadCompleteTitle => 'ดาวน์โหลดเสร็จแล้ว';

  @override
  String get backgroundDownloadFailedTitle => 'ดาวน์โหลดไม่สำเร็จ';

  @override
  String get onboardingBack => 'ย้อนกลับ';

  @override
  String get onboardingContinue => 'ดำเนินการต่อ';

  @override
  String get onboardingExamPrompt => 'ตอนนี้คุณกำลังเตรียมสอบอะไรอยู่?';

  @override
  String get onboardingExamGaokao => 'Gaokao ของจีน';

  @override
  String get onboardingExamCet => 'CET-4 / CET-6';

  @override
  String get onboardingExamTem => 'TEM-4 / TEM-8';

  @override
  String get onboardingExamIelts => 'IELTS';

  @override
  String get onboardingExamToefl => 'TOEFL';

  @override
  String get onboardingExamOther => 'อื่น ๆ';

  @override
  String get onboardingSummaryEyebrow => 'รู้หรือไม่?';

  @override
  String get onboardingSummaryHeadline =>
      'การพัฒนาการฟังและการพูด\nไม่ใช่การฝึกด้วยสื่อมากขึ้น\nแต่คือการฝึกให้ลึกซึ้งยิ่งขึ้น';

  @override
  String get onboardingSummaryPoint1 => 'ฝึกด้วยเสียงที่เหมาะกับระดับของคุณ';

  @override
  String get onboardingSummaryPoint2 =>
      'เข้าใจสิ่งที่ได้ยินเป็นกลุ่มคำ และเชี่ยวชาญคำศัพท์ในบริบท';

  @override
  String get onboardingSummaryPoint3 =>
      'พัฒนาความคุ้นเคยกับภาษาเยอรมันอย่างเป็นธรรมชาติผ่านการฟังอย่างใกล้ชิดและฝึกซ้ำอย่างต่อเนื่อง';

  @override
  String get onboardingSummaryPoint4 =>
      'ฝึกพูดผ่านการเล่าเรื่องซ้ำ และเปลี่ยนสิ่งที่ได้ยินให้เป็นสิ่งที่คุณพูดได้';

  @override
  String get onboardingStart => 'เริ่มฝึก';

  @override
  String get onboardingQ1Prompt =>
      'เป้าหมายหลักของคุณในการพัฒนาการฟังและการพูดคืออะไร?';

  @override
  String get onboardingQ1OptionExam => 'เพื่อการสอบ';

  @override
  String get onboardingQ1OptionDaily => 'บทสนทนาในชีวิตประจำวัน';

  @override
  String get onboardingQ1OptionWork => 'การทำงาน';

  @override
  String get onboardingQ1OptionTravel => 'ท่องเที่ยวต่างประเทศ';

  @override
  String get onboardingQ1OptionContent => 'วิดีโอและพอดแคสต์';

  @override
  String get onboardingQ1OptionOther => 'อื่น ๆ';

  @override
  String get onboardingQ2Prompt => 'คุณวางแผนจะฝึกวันละนานเท่าไร?';

  @override
  String get onboardingQ2Option5 => 'ประมาณ 5 นาที';

  @override
  String get onboardingQ2Option10 => 'ประมาณ 10 นาที';

  @override
  String get onboardingQ2Option20 => 'ประมาณ 20 นาที';

  @override
  String get onboardingQ2Option30 => '30+ นาที';

  @override
  String get onboardingQ3Prompt => 'คุณรู้จักเราจากไหน?';

  @override
  String get onboardingQ3OptionAppStore => 'App Store';

  @override
  String get onboardingQ3OptionYoutube => 'YouTube';

  @override
  String get onboardingQ3OptionReddit => 'Reddit';

  @override
  String get onboardingQ3OptionXTwitter => 'X / Twitter';

  @override
  String get onboardingQ3OptionXiaohongshu => 'Xiaohongshu';

  @override
  String get onboardingQ3OptionWechat => 'WeChat';

  @override
  String get onboardingQ3OptionBilibili => 'Bilibili';

  @override
  String get onboardingQ3OptionGithub => 'GitHub';

  @override
  String get onboardingQ3OptionFriend => 'เพื่อน';

  @override
  String get onboardingQ3OptionOther => 'อื่น ๆ';

  @override
  String get onboardingQ3OptionShortVideo => 'วิดีโอสั้น';

  @override
  String get onboardingQ3OptionSearchEngine => 'เครื่องมือค้นหา';

  @override
  String get onboardingQ3OptionAiAssistant => 'ผู้ช่วย AI';

  @override
  String get onboardingQ3OptionTeacherSchool => 'ครูหรือโรงเรียน';

  @override
  String get onboardingQ3OtherHint => 'ไม่บังคับ: คุณรู้จักเราจากไหน?';

  @override
  String get onboardingPermissionsHint =>
      'เพื่อประสบการณ์ที่ดีที่สุด เราจะขอสิทธิ์การเข้าถึงเหล่านี้';

  @override
  String get onboardingPermissionsNotification => 'การแจ้งเตือน';

  @override
  String get onboardingPermissionsMicrophone => 'ไมโครโฟน';

  @override
  String get onboardingPermissionsSpeech => 'การรู้จำเสียงพูด';

  @override
  String get playbackSection => 'การเล่น';

  @override
  String get learningSection => 'การเรียนรู้';

  @override
  String get learningSettings => 'การตั้งค่าการเรียนรู้';

  @override
  String get dailyGoalSetting => 'เป้าหมายการเรียนประจำวัน';

  @override
  String get dailyGoalSettingSubtitle =>
      'ระยะเวลาที่คุณวางแผนจะเรียนในแต่ละวัน';

  @override
  String dailyGoalMinutesValue(int minutes) {
    return '$minutes นาที';
  }

  @override
  String get activityDayCheckedInSemantics => ', บรรลุเป้าหมายประจำวันแล้ว';

  @override
  String get dailyGoalTodayTitle => 'เป้าหมายของวันนี้';

  @override
  String dailyGoalStudiedLabel(int minutes) {
    return 'เรียนแล้ว $minutes นาที';
  }

  @override
  String dailyGoalTargetLabel(int minutes) {
    return 'เป้าหมาย $minutes นาที';
  }

  @override
  String get dailyGoalTodayCheckedIn => 'เช็กอินวันนี้แล้ว';

  @override
  String get monthlyCheckInDays => 'วันเช็กอิน';

  @override
  String get activityLegendCheckedIn => 'ทำเป้าหมายรายวันสำเร็จ';

  @override
  String get dailyGoalAchievedTitle => 'Daily goal achieved!';

  @override
  String dailyGoalCompletedToast(int minutes) {
    return 'เป้าหมายการเรียน $minutes นาทีวันนี้สำเร็จแล้ว!';
  }

  @override
  String get showRecommendationToggle => 'แสดงการ์ดแนะนำ';

  @override
  String get showRecommendationSubtitle =>
      'แสดงการ์ด \"แนะนำสำหรับคุณ\" ในหน้าเรียน';

  @override
  String get hideRecommendationTooltip => 'ซ่อนคำแนะนำ';

  @override
  String get hideRecommendationTitle => 'ซ่อนการ์ดแนะนำ?';

  @override
  String get hideRecommendationMessage =>
      'หน้าเรียนจะหยุดแสดงคำแนะนำ หากต้องการให้กลับมา ให้เปิดอีกครั้งในโปรไฟล์ › การตั้งค่าการแสดงผล';

  @override
  String get showWeeklyChartToggle => 'แสดงกราฟการเรียนรายสัปดาห์';

  @override
  String get showWeeklyChartSubtitle =>
      'แสดงกราฟเวลาเรียนรายสัปดาห์ในหน้าเรียน';

  @override
  String get showPlaybackSpeedButtonToggle => 'แสดงปุ่มความเร็วการเล่น';

  @override
  String get showPlaybackSpeedButtonSubtitle =>
      'แสดงปุ่มความเร็วการเล่นในตัวควบคุมการเล่นของงานเรียน';

  @override
  String get playbackSpeedDragHint => 'เลื่อนซ้ายหรือขวา · ปล่อยเพื่อใช้งาน';

  @override
  String get hideWeeklyChartTooltip => 'ซ่อนกราฟรายสัปดาห์';

  @override
  String get hideWeeklyChartTitle => 'ซ่อนกราฟการเรียนรายสัปดาห์?';

  @override
  String get hideWeeklyChartMessage =>
      'หน้าเรียนจะหยุดแสดงกราฟการเรียนรายสัปดาห์ หากต้องการให้กลับมา ให้เปิดอีกครั้งในโปรไฟล์ › การตั้งค่าการแสดงผล';

  @override
  String get speakingPracticeSection => 'ฝึกพูด';

  @override
  String get autoSkipRetellToggle => 'ข้ามการฝึกเล่าเรื่องอัตโนมัติ';

  @override
  String get autoSkipRetellSubtitle =>
      'ข้ามงานเล่าเรื่องในแผนการเรียนโดยอัตโนมัติ';

  @override
  String get autoShowAiExplanationToggle => 'แสดงคำอธิบาย AI อัตโนมัติ';

  @override
  String get autoShowAiExplanationSubtitle =>
      'แสดงความช่วยเหลือ AI ที่เลือกไว้อัตโนมัติเมื่อเข้าสู่คำอธิบายประโยค';

  @override
  String get autoShowAiAnalysisToggle => 'การวิเคราะห์ AI';

  @override
  String get autoShowAiTranslationToggle => 'คำแปล AI';

  @override
  String get autoShowAiSenseGroupsToggle => 'กลุ่มความหมาย AI';

  @override
  String get autoPlayRetellRecordingToggle =>
      'เล่นไฟล์บันทึกการเล่าเรื่องอัตโนมัติ';

  @override
  String get autoPlayRetellRecordingSubtitle =>
      'หลังการเล่าเรื่องแต่ละครั้ง เล่นไฟล์บันทึกของคุณอัตโนมัติเพื่อตรวจการออกเสียง';

  @override
  String get listenAndRepeatRatingToggle => 'แสดงคะแนนหลังพูดตามแต่ละครั้ง';

  @override
  String get listenAndRepeatRatingSubtitle =>
      'เมื่อปิด ไฟล์บันทึกจะยังถูกเก็บไว้ แต่จะข้ามการรู้จำและการให้คะแนน';

  @override
  String get retellRatingToggle => 'แสดงคะแนนหลังเล่าเรื่องแต่ละครั้ง';

  @override
  String get retellRatingSubtitle =>
      'เมื่อปิด คุณยังเล่นไฟล์บันทึกได้ แต่จะไม่แสดงคะแนน';

  @override
  String get autoSaveOnUnclearToggle =>
      'บันทึกอัตโนมัติเมื่อทำเครื่องหมายว่าไม่ชัดเจน';

  @override
  String get autoSaveOnUnclearSubtitle =>
      'เมื่อเปิด การแตะ \"ไม่ชัดเจน\" ในการฟังแบบเข้มข้นจะบันทึกประโยค';

  @override
  String get unclearAutoSaveDialogTitle => 'บันทึกประโยคที่ไม่ชัดเจนอัตโนมัติ';

  @override
  String get unclearAutoSaveDialogMessage =>
      'เมื่อคุณแตะ \"ไม่ชัดเจน\" ประโยคจะถูกบันทึกอัตโนมัติเพื่อให้คุณกลับมาทบทวนภายหลัง';

  @override
  String get unclearAutoSaveSwitchOn => 'เปิด';

  @override
  String get unclearAutoSaveSwitchOff => 'ปิด';

  @override
  String get unclearAutoSaveDialogHint =>
      'คุณเปลี่ยนได้ทุกเมื่อใน ฉัน → การตั้งค่าการเรียน';

  @override
  String get unclearAutoSaveDialogConfirm => 'เข้าใจแล้ว';

  @override
  String get retellSkip => 'ข้าม';

  @override
  String get retellSkippedSuffix => 'ข้ามแล้ว';

  @override
  String get skipSilenceTitle => 'ข้ามช่วงเงียบอัตโนมัติ';

  @override
  String get skipSilenceDescription => 'ข้ามช่วงเงียบยาวระหว่างประโยค';

  @override
  String get wordHighlightTitle => 'ไฮไลต์คำระหว่างเล่น';

  @override
  String get wordHighlightDescription => 'ไฮไลต์แต่ละคำขณะถูกพูดในเสียงต้นฉบับ';

  @override
  String get resumeFromSentenceStartTitle => 'เล่นซ้ำตั้งแต่ต้นประโยค';

  @override
  String get resumeFromSentenceStartEnabledDescription =>
      'เมื่อเล่นประโยคปัจจุบันซ้ำ จะเริ่มเล่นตั้งแต่ต้นประโยค';

  @override
  String get resumeFromSentenceStartDisabledDescription =>
      'เมื่อเล่นประโยคปัจจุบันซ้ำ จะเล่นต่อจากจุดที่คุณหยุด';

  @override
  String get silenceThreshold => 'เกณฑ์ความเงียบ';

  @override
  String silenceThresholdValue(int seconds) {
    return '$seconds วินาที';
  }

  @override
  String silenceSkipped(int seconds) {
    return 'ข้ามช่วงเงียบ $seconds วินาที';
  }

  @override
  String get speechPermDialogTitleRequest => 'ต้องอนุญาตสิทธิ์';

  @override
  String get speechPermDialogTitleDenied => 'สิทธิ์ถูกปฏิเสธ';

  @override
  String get speechPermDialogTitleRestricted => 'อุปกรณ์ถูกจำกัด';

  @override
  String get speechPermItemMic => 'ไมโครโฟน';

  @override
  String get speechPermItemMicDesc =>
      'บันทึกเสียงพูดของคุณเพื่อประเมินการออกเสียง';

  @override
  String get speechPermItemSpeech => 'การรู้จำเสียงพูด';

  @override
  String get speechPermItemSpeechDesc => 'ตรวจจับคำที่ออกเสียงไม่ถูกต้อง';

  @override
  String get speechPermStatusPending => 'ยังไม่ได้รับอนุญาต';

  @override
  String get speechPermStatusDenied => 'ถูกปฏิเสธ';

  @override
  String get speechPermDeniedHint =>
      'คุณเคยปฏิเสธการเข้าถึง โปรดเปิดใช้งานในการตั้งค่าระบบ';

  @override
  String get speechPermRestrictedHint =>
      'การบันทึกเสียงถูกจำกัดบนอุปกรณ์นี้โดยการควบคุมของผู้ปกครองหรือ MDM';

  @override
  String get speechPermActionGrant => 'อนุญาต';

  @override
  String get speechPermActionOpenSettings => 'เปิดการตั้งค่า';

  @override
  String get speechPermUnsupportedToast =>
      'แพลตฟอร์มนี้ไม่รองรับการบันทึกเสียง';

  @override
  String get authSignInTitle => 'ลงชื่อเข้าใช้ Echo Loop';

  @override
  String get authContinueWithEmail => 'ดำเนินการต่อด้วยรหัสอีเมล';

  @override
  String get authContinueWithApple => 'ดำเนินการต่อด้วย Apple';

  @override
  String get authContinueWithGoogle => 'ดำเนินการต่อด้วย Google';

  @override
  String get authGoogleUnavailable =>
      'ลงชื่อเข้าใช้ด้วย Google ไม่พร้อมใช้งานบนอุปกรณ์นี้ โปรดใช้รหัสอีเมลแทน';

  @override
  String get authGoogleServicesOutdated =>
      'บริการ Google ล้าสมัย โปรดอัปเดตแล้วลองอีกครั้ง';

  @override
  String get authEmailOtpDescription =>
      'กรอกอีเมลของคุณ แล้วเราจะส่งรหัสใช้ครั้งเดียวให้';

  @override
  String get authEmailOtpAutoCreateHint =>
      'การใช้งานครั้งแรกจะสร้างบัญชีของคุณโดยอัตโนมัติ';

  @override
  String get authEmailLabel => 'อีเมล';

  @override
  String get authOtpLabel => 'รหัส 6 หลัก';

  @override
  String get authOtpRequired => 'กรอกรหัส 6 หลัก';

  @override
  String get authOtpInvalid => 'กรอกรหัส 6 หลักที่ถูกต้อง';

  @override
  String get authOtpIncorrectOrExpired => 'รหัสยืนยันไม่ถูกต้องหรือหมดอายุ';

  @override
  String get authOtpHelpText => 'หากไม่พบอีเมล โปรดตรวจสอบในสแปม';

  @override
  String get authSendOtpButton => 'ส่งรหัส';

  @override
  String get authSendingOtp => 'กำลังส่งรหัส';

  @override
  String get authVerifyOtpButton => 'ดำเนินการต่อ';

  @override
  String get authVerifyingOtp => 'กำลังตรวจสอบ';

  @override
  String get authResendOtpButton => 'ส่งรหัสอีกครั้ง';

  @override
  String authResendOtpCountdown(int seconds) {
    return 'อีก $seconds วินาทีจึงส่งใหม่ได้';
  }

  @override
  String get authOtpResent => 'ส่งรหัสใหม่แล้ว';

  @override
  String get authPasswordLabel => 'รหัสผ่าน';

  @override
  String get authSignInButton => 'เข้าสู่ระบบ';

  @override
  String get authSigningIn => 'กำลังเข้าสู่ระบบ';

  @override
  String get authCheckEmailTitle => 'ตรวจสอบอีเมลของคุณ';

  @override
  String authCheckEmailMessage(String email) {
    return 'เราได้ส่งรหัส 6 หลักไปที่ $email';
  }

  @override
  String get authEmailRequired => 'กรอกอีเมลของคุณ';

  @override
  String get authEmailInvalid => 'กรอกอีเมลที่ถูกต้อง';

  @override
  String get authPasswordRequired => 'กรอกรหัสผ่านของคุณ';

  @override
  String get authPasswordTooShort => 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';

  @override
  String get authUnavailable => 'ยังไม่ได้ตั้งค่าการยืนยันตัวตน';

  @override
  String get authUnknownError => 'เกิดข้อผิดพลาด โปรดลองอีกครั้ง';

  @override
  String get authTermsAgreementPrefix => 'ฉันได้อ่านและยอมรับ';

  @override
  String get authTermsContinuationPrefix => 'การดำเนินการต่อถือว่าคุณยอมรับ';

  @override
  String get authTermsJoiner => ' และ ';

  @override
  String get authTermsOfService => 'ข้อกำหนดการให้บริการ';

  @override
  String get authPrivacyPolicy => 'นโยบายความเป็นส่วนตัว';

  @override
  String get authSignedInStatus => 'เข้าสู่ระบบแล้ว';

  @override
  String get authSignedOutStatus => 'ออกจากระบบแล้ว';

  @override
  String get authSignedInWithApple => 'เข้าสู่ระบบด้วย Apple';

  @override
  String get authSignedInWithGoogle => 'เข้าสู่ระบบด้วย Google';

  @override
  String get authAppleAccount => 'บัญชี Apple';

  @override
  String get authEmailUnavailable => 'ไม่สามารถใช้อีเมลได้';

  @override
  String get authGoogleAccount => 'บัญชี Google';

  @override
  String get authSignOut => 'ออกจากระบบ';

  @override
  String get editSubtitles => 'แก้ไขคำบรรยาย';

  @override
  String get mergeWithNextSentence => 'รวมกับประโยคถัดไป';

  @override
  String get deleteSentence => 'ลบประโยค';

  @override
  String get playSentence => 'เล่นประโยค';

  @override
  String get stopPlayback => 'หยุดเล่น';

  @override
  String get editWord => 'แก้ไขคำ';

  @override
  String get splitSentenceHere => 'แยกประโยคตรงนี้';

  @override
  String get wordEditAction => 'แก้ไข';

  @override
  String get wordSplitBeforeAction => 'แยก';

  @override
  String get redo => 'Redo';

  @override
  String get mergeWithPreviousSentence => 'Merge with previous';

  @override
  String get subtitleEditSentenceText => 'Edit text';

  @override
  String get subtitleInsertSentenceAbove => 'Insert sentence above';

  @override
  String get subtitleInsertSentenceBelow => 'Insert sentence below';

  @override
  String get subtitleInsertSentenceNoGap =>
      'No gap here. Drag boundaries to make room first.';

  @override
  String get subtitleAddSentenceHere => 'Add sentence';

  @override
  String get subtitleNewSentenceHint => 'Type the new sentence';

  @override
  String get subtitleTextEditHint => 'Enter to save · Esc to cancel';

  @override
  String get insertWordBefore => 'Insert word before';

  @override
  String get insertWordAfter => 'Insert word after';

  @override
  String get deleteWord => 'Delete word';

  @override
  String get subtitleNewWordHint => 'New word';

  @override
  String get subtitleEditsSaved => 'บันทึกการเปลี่ยนแปลงคำบรรยายแล้ว';

  @override
  String get discardSubtitleEditsTitle => 'ทิ้งการเปลี่ยนแปลง?';

  @override
  String get discardSubtitleEditsMessage =>
      'การเปลี่ยนแปลงคำบรรยายของคุณยังไม่ได้ถูกบันทึก';

  @override
  String get discard => 'ทิ้ง';

  @override
  String get importAudio => 'นำเข้าเสียง';

  @override
  String get importAudioFromFile => 'นำเข้าจากไฟล์';

  @override
  String get importAudioFromUrl => 'นำเข้าจากลิงก์';

  @override
  String get importAudioFromUrlDescription =>
      'วางลิงก์เสียงโดยตรงแล้วดาวน์โหลด';

  @override
  String get importAudioFromCloudDrive => 'นำเข้าจากพื้นที่จัดเก็บคลาวด์';

  @override
  String get baiduNetdisk => 'Baidu Netdisk';

  @override
  String get baiduNetdiskAllFiles => 'ไฟล์ทั้งหมด';

  @override
  String get baiduNetdiskWaitingAuthorization => 'กำลังรอการอนุญาตจาก Baidu...';

  @override
  String get baiduNetdiskLoadingFiles => 'กำลังโหลดไฟล์จาก Baidu Netdisk...';

  @override
  String get baiduNetdiskImportFailed => 'นำเข้าจาก Baidu Netdisk ไม่สำเร็จ';

  @override
  String get baiduNetdiskConnectTitle => 'เชื่อมต่อ Baidu Netdisk';

  @override
  String get baiduNetdiskConnectDescription =>
      'อนุญาตให้ Echo Loop เรียกดู Baidu Netdisk ของคุณและนำเข้าไฟล์สื่อที่เลือก';

  @override
  String get baiduNetdiskConnectAction => 'เชื่อมต่อ Baidu Netdisk';

  @override
  String get baiduNetdiskSelectAllAction => 'เลือก';

  @override
  String get baiduNetdiskClearSelectionAction => 'ล้าง';

  @override
  String get baiduNetdiskAccountTooltip => 'บัญชี Baidu Netdisk';

  @override
  String get baiduNetdiskAccountTitle => 'บัญชี Baidu Netdisk';

  @override
  String get baiduNetdiskUsername => 'ชื่อผู้ใช้ Baidu';

  @override
  String get baiduNetdiskNetdiskName => 'ชื่อเล่น Baidu Netdisk';

  @override
  String get baiduNetdiskMembership => 'สมาชิก';

  @override
  String get baiduNetdiskUnavailable => 'ไม่ได้ระบุ';

  @override
  String get baiduNetdiskDisconnect => 'ยกเลิกการเชื่อมต่อ Baidu Netdisk';

  @override
  String get importAudioShort => 'นำเข้า';

  @override
  String get cancelImport => 'ยกเลิกการนำเข้า';

  @override
  String get cancelingImport => 'กำลังยกเลิกการนำเข้า…';

  @override
  String importAudioAndSubtitleCount(int audioCount, int subtitleCount) {
    String _temp0 = intl.Intl.pluralLogic(
      audioCount,
      locale: localeName,
      other: '$audioCount รายการ',
      one: '1 รายการ',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subtitleCount,
      locale: localeName,
      other: ', คำบรรยาย $subtitleCount รายการ',
      one: ', คำบรรยาย 1 รายการ',
      zero: '',
    );
    return 'นำเข้า ($_temp0$_temp1)';
  }

  @override
  String get audioUrlLabel => 'ลิงก์เสียง';

  @override
  String get audioUrlHint => 'https://example.com/audio.mp3';

  @override
  String get pasteAudioLink => 'วางลิงก์';

  @override
  String get audioClipboardNoValidLink => 'คลิปบอร์ดไม่มีลิงก์ที่ถูกต้อง';

  @override
  String get downloadAndImportAudio => 'ดาวน์โหลดและนำเข้า';

  @override
  String get audioUrlInvalid => 'ป้อนลิงก์เสียงที่ถูกต้อง';

  @override
  String get audioUrlUnsupported => 'ลิงก์นี้ไม่ใช่รูปแบบไฟล์เสียงที่รองรับ';

  @override
  String get audioUrlNotDirectAudio => 'ลิงก์นี้ไม่ใช่ไฟล์เสียงโดยตรง';

  @override
  String get audioUrlDuplicate => 'มีไฟล์เสียงชื่อนี้อยู่แล้ว';

  @override
  String get audioDownloadFailed => 'ดาวน์โหลดเสียงไม่สำเร็จ';

  @override
  String get audioDownloadInProgress => 'กำลังดาวน์โหลด';

  @override
  String get audioQueued => 'อยู่ในคิว';

  @override
  String get audioNotDownloaded => 'Not downloaded';

  @override
  String get audioDownloaded => 'Downloaded';

  @override
  String get audioDownloading => 'Downloading';

  @override
  String get baiduImportedToLibrary => 'นำเข้าสู่คลังแล้ว';

  @override
  String baiduImportedToCollections(String names) {
    return 'นำเข้าสู่: $names';
  }

  @override
  String get baiduImportDuplicate => 'มีอยู่แล้ว';

  @override
  String get baiduSubtitleUnmatched => 'ไม่พบไฟล์เสียงที่ตรงกัน';

  @override
  String get baiduDisconnectActiveTitle => 'กำลังนำเข้าอยู่';

  @override
  String baiduDisconnectActiveMessage(int count) {
    return '$count ไฟล์กำลังดาวน์โหลดหรืออยู่ในคิว การตัดการเชื่อมต่อจะยกเลิกไฟล์เหล่านี้';
  }

  @override
  String get mediaQueued => 'อยู่ในคิว...';

  @override
  String get audioImportComplete => 'นำเข้าเสร็จสิ้น';

  @override
  String get audioImportCanceled => 'ยกเลิกการนำเข้าเสียงแล้ว';

  @override
  String get cancelDownload => 'ยกเลิกการดาวน์โหลด';

  @override
  String get subscribePodcast => 'สมัครรับพอดแคสต์';

  @override
  String get subscribePodcastOptionDescription =>
      'เพิ่มด้วย Apple Podcasts หรือ RSS';

  @override
  String get podcastUrlLabel => 'URL ของ Apple Podcasts หรือ RSS';

  @override
  String get podcastUrlHint =>
      'https://podcasts.apple.com/... หรือ https://…/feed.xml';

  @override
  String get podcastSearchHint => 'ค้นหาพอดแคสต์หรือวางลิงก์';

  @override
  String get podcastSearchEmpty => 'ไม่พบพอดแคสต์';

  @override
  String get podcastSearchFailed => 'ค้นหาล้มเหลว โปรดลองอีกครั้ง';

  @override
  String get podcastSubscribeThisLink => 'สมัครรับลิงก์นี้';

  @override
  String get podcastSubscribing => 'กำลังดึงฟีดพอดแคสต์…';

  @override
  String podcastSubscribeFailed(String error) {
    return 'สมัครรับไม่สำเร็จ: $error';
  }

  @override
  String podcastRefreshFailed(String error) {
    return 'รีเฟรชไม่สำเร็จ: $error';
  }

  @override
  String podcastAlreadySubscribed(String name) {
    return 'สมัครรับแล้ว — ดูคอลเลกชัน \"$name\"';
  }

  @override
  String get podcastRefreshFeed => 'รีเฟรชฟีด';

  @override
  String get podcastUnsubscribe => 'ยกเลิกการสมัครรับ';

  @override
  String podcastUnsubscribeConfirmTitle(String name) {
    return 'ยกเลิกการสมัครรับจาก $name?';
  }

  @override
  String get podcastUnsubscribeConfirmMessage =>
      'ตอนทั้งหมดและไฟล์เสียงที่ดาวน์โหลดในคอลเลกชันนี้จะถูกลบ';

  @override
  String get podcastFeedInfo => 'ข้อมูลฟีด';

  @override
  String get podcastDetails => 'รายละเอียด';

  @override
  String get podcastEpisodeMeta => 'ข้อมูลตอน';

  @override
  String get podcastShowMore => 'เพิ่มเติม';

  @override
  String get podcastShowLess => 'น้อยลง';

  @override
  String get podcastTitle => 'ชื่อเรื่อง';

  @override
  String get podcastAuthor => 'ผู้จัดรายการ';

  @override
  String get podcastFeedUrl => 'URL ของ RSS';

  @override
  String get podcastAppleLink => 'Apple Podcasts';

  @override
  String get podcastOriginalLink => 'ลิงก์';

  @override
  String get podcastAudioType => 'ประเภทเสียง';

  @override
  String get podcastOpenLinkFailed => 'ไม่สามารถเปิดลิงก์ได้';

  @override
  String podcastLastRefreshed(String time) {
    return 'รีเฟรชล่าสุด: $time';
  }

  @override
  String get podcastEpisodeGuid => 'GUID';

  @override
  String get podcastEnclosureUrl => 'URL เสียง';

  @override
  String get soundEffects => 'Sound Effects';

  @override
  String get soundSettings => 'Sound';

  @override
  String get ttsSettings => 'แปลงข้อความเป็นเสียง';

  @override
  String get ttsSettingsDescription =>
      'เลือกเครื่องยนต์เสียงและสำเนียงที่ใช้เมื่ออ่านคำและประโยคตัวอย่างออกเสียง';

  @override
  String get ttsEngine => 'เครื่องยนต์เสียง';

  @override
  String get ttsEnginePlatform => 'เสียงของระบบ';

  @override
  String get ttsEnginePlatformApple => 'Apple AI';

  @override
  String get ttsEnginePlatformDescription =>
      'มีอยู่ในอุปกรณ์ของคุณ เร็ว ไม่ต้องดาวน์โหลด คุณภาพปานกลาง';

  @override
  String get ttsEngineEchoLoop => 'Echo Loop AI (ขั้นสูง)';

  @override
  String get ttsEngineEchoLoopDescription =>
      'คุณภาพเสียงดีที่สุด ต้องดาวน์โหลดโมเดล แนะนำสำหรับอุปกรณ์ประสิทธิภาพสูง';

  @override
  String get ttsEnginePiper => 'Echo Loop AI (สมดุล)';

  @override
  String get ttsEnginePiperDescription =>
      'เสียงเป็นธรรมชาติและลื่นไหล ต้องดาวน์โหลดโมเดล แนะนำสำหรับอุปกรณ์ระดับกลาง';

  @override
  String get ttsEngineEdge => 'Edge TTS';

  @override
  String get ttsEngineEdgeDescription =>
      'ใช้เสียงประสาทของ Microsoft เพื่อการออกเสียงที่เป็นธรรมชาติ ต้องเชื่อมต่ออินเทอร์เน็ต';

  @override
  String get edgeTtsUnavailableTitle => 'Edge Online Voice ไม่พร้อมใช้งาน';

  @override
  String get edgeTtsUnavailableNetworkMessage =>
      'คุณออฟไลน์อยู่ Edge Online Voice ต้องเชื่อมต่ออินเทอร์เน็ต ตรวจสอบเครือข่ายแล้วลองอีกครั้ง หรือเลือกเครื่องยนต์เสียงอื่นในการตั้งค่า';

  @override
  String get edgeTtsUnavailableServiceMessage =>
      'Edge Online Voice ไม่พร้อมใช้งานชั่วคราว คุณสามารถเลือกเครื่องยนต์เสียงอื่นในการตั้งค่า';

  @override
  String get edgeTtsUnavailableDismiss => 'ตกลง';

  @override
  String get ttsModel => 'โมเดล';

  @override
  String get ttsModelHighQuality => 'คุณภาพสูง';

  @override
  String get ttsModelHighQualityDescription =>
      'เสียงดีที่สุดด้วยความเร็วที่ยอมรับได้ ประมาณ 300 MB';

  @override
  String get ttsModelLite => 'น้ำหนักเบา';

  @override
  String get ttsModelLiteDescription =>
      'ขนาดเล็กและประหยัดหน่วยความจำสำหรับอุปกรณ์ระดับล่าง แต่ช้ากว่า ประมาณ 100 MB';

  @override
  String get ttsModelRecommended => 'แนะนำ';

  @override
  String get ttsModelNotDownloaded => 'ยังไม่ได้ดาวน์โหลด';

  @override
  String get ttsModelDownloadRequiredTitle =>
      'จำเป็นต้องมีโมเดลสังเคราะห์เสียง';

  @override
  String get ttsModelDownloadIntro => 'เสียงนี้ต้องดาวน์โหลดโมเดลหนึ่งครั้ง';

  @override
  String ttsModelDownloadEstimate(Object size) {
    return 'ขนาดดาวน์โหลดโดยประมาณ: ~$size';
  }

  @override
  String get ttsModelDownloadSettingsHint =>
      'คุณยังสามารถเลือกโมเดลเสียงอื่นในการตั้งค่าได้';

  @override
  String get ttsModelDownloadingTitle => 'กำลังดาวน์โหลดโมเดลสังเคราะห์เสียง';

  @override
  String ttsModelDownloadingMessage(Object size) {
    return 'ขนาดดาวน์โหลดโดยประมาณ: ~$size';
  }

  @override
  String ttsModelDownloadProgress(Object progress) {
    return 'เสร็จสิ้น $progress';
  }

  @override
  String get ttsModelDownloadFailedTitle =>
      'ดาวน์โหลดโมเดลสังเคราะห์เสียงไม่สำเร็จ';

  @override
  String ttsModelDownloadFailedMessage(Object size) {
    return 'การดาวน์โหลดไม่เสร็จสมบูรณ์ ขนาดดาวน์โหลดโดยประมาณ: ~$size';
  }

  @override
  String get ttsDownloadModel => 'ดาวน์โหลดโมเดล';

  @override
  String get ttsAccent => 'สำเนียง';

  @override
  String get ttsAccentUs => 'เยอรมัน (หญิง)';

  @override
  String get ttsAccentUk => 'เยอรมัน (ชาย)';

  @override
  String get ttsAccentHint => '(ฉบับภาษาเยอรมัน: จัดกลุ่มตามเสียงหญิง / ชาย)';

  @override
  String get ttsVoice => 'เสียง';

  @override
  String get ttsVoiceFemale => 'หญิง';

  @override
  String get ttsVoiceMale => 'ชาย';

  @override
  String get ttsDeleteModel => 'ลบโมเดล';

  @override
  String get ttsDeleteModelConfirm =>
      'ลบโมเดลเสียง Echo Loop หรือไม่ คุณสามารถดาวน์โหลดใหม่ได้ทุกเมื่อ';

  @override
  String get ttsCancelDownload => 'ยกเลิก';

  @override
  String get ttsDownloadedModelsTitle => 'โมเดล Echo Loop ที่ดาวน์โหลดแล้ว';

  @override
  String ttsDownloadedModelsDesc(String size) {
    return 'ไม่ได้ใช้งาน · $size';
  }

  @override
  String get asrDeleteAllModelsConfirm =>
      'ลบโมเดลรู้จำเสียง Echo Loop ที่ดาวน์โหลดไว้ทั้งหมดหรือไม่ คุณสามารถดาวน์โหลดใหม่ได้ทุกเมื่อ';

  @override
  String get asrDownloadedModelsTitle => 'โมเดลรู้จำเสียงที่ดาวน์โหลดแล้ว';

  @override
  String asrDownloadedModelsDesc(String size) {
    return 'ไม่ได้ใช้งาน · $size';
  }

  @override
  String get dictionarySettings => 'การตั้งค่าพจนานุกรม';

  @override
  String get dictionaryDefault => 'พจนานุกรมเริ่มต้น';

  @override
  String get dictionaryDefaultDescription =>
      'พจนานุกรมที่แสดงโดยค่าเริ่มต้นเมื่อค้นหาคำ';

  @override
  String get dictionarySources => 'แหล่งพจนานุกรม';

  @override
  String get dictionarySourcesDescription =>
      'พจนานุกรมที่ปิดใช้งานจะไม่ปรากฏในตัวสลับการค้นหา';

  @override
  String get dictionaryAutoSpeakOnLookup => 'เล่นการออกเสียงอัตโนมัติ';

  @override
  String get dictionaryAutoShowAiOnLookup => 'Auto-show AI Lookup';

  @override
  String get lookupSettingsTitle => 'Lookup Settings';

  @override
  String get lookupSettingsTooltip => 'Lookup settings';

  @override
  String get lookupAutoSpeak => 'Auto-play pronunciation';

  @override
  String get lookupSearchHint => 'Enter a German word or phrase';

  @override
  String get lookupRecentTitle => 'Recent';

  @override
  String get lookupClearHistory => 'Clear';

  @override
  String get lookupClearHistoryConfirm => 'Clear all lookup history?';

  @override
  String get lookupHistoryEmpty => 'Words you look up will appear here';

  @override
  String get lookupWordlistUnavailable =>
      'Word list unavailable. You can still look up words directly.';

  @override
  String get dictionaryAdFilterTitle => 'บล็อกโฆษณาในพจนานุกรมเว็บ';

  @override
  String get dictSourceLocal => 'พจนานุกรมพื้นฐาน';

  @override
  String get dictSourceAi => 'พจนานุกรม AI';

  @override
  String get dictSourceAlwaysOn => 'เปิดเสมอ';

  @override
  String dictSourceCannotDisable(String name) {
    return '$name เป็นแหล่งพื้นฐานและไม่สามารถปิดใช้งานได้';
  }

  @override
  String get dictDefaultBadge => 'ค่าเริ่มต้น';

  @override
  String dictSwitcherSemantics(String name) {
    return 'สลับพจนานุกรม ขณะนี้คือ $name';
  }

  @override
  String get dictCambridgeOpenInBrowser => 'เปิดในเบราว์เซอร์';

  @override
  String get aiNoAnalysis => 'ไม่มีผลวิเคราะห์จาก AI';

  @override
  String get aiSignInRequired => 'ลงชื่อเข้าใช้เพื่อใช้พจนานุกรม AI';

  @override
  String get dictPhraseTooLong => 'วลียาวเกินไป เลือกได้สูงสุด 8 คำ';

  @override
  String get dictAiSynonyms => 'คำพ้องความหมาย';

  @override
  String get dictAiAntonyms => 'คำตรงข้าม';

  @override
  String get dictAiExpressions => 'คำที่ใช้ร่วมกัน';

  @override
  String get dictAiWordFamily => 'ตระกูลคำ';

  @override
  String get dictAiForms => 'รูปคำ';

  @override
  String get dictAiEtymology => 'รากศัพท์';

  @override
  String get dictAiTips => 'เคล็ดลับการเรียนรู้';

  @override
  String get dictAiMultiKeyPoints => 'บันทึกการเรียน';

  @override
  String get dictAiMultiMeanings => 'ความหมายและตัวอย่าง';

  @override
  String get dictAiMultiNaturalness => 'การแก้ไข';

  @override
  String get dictAiMultiPronunciationTips => 'การออกเสียง';

  @override
  String get dictAiMultiSimilarExpressions => 'สำนวนที่คล้ายกัน';

  @override
  String get dictAiMultiBackground => 'ความรู้เบื้องหลัง';

  @override
  String get chatOpenTooltip => 'ถาม AI';

  @override
  String get chatSentenceTitle => 'ติวเตอร์ AI';

  @override
  String get chatInputPlaceholder => 'ถามอะไรก็ได้…';

  @override
  String get chatSend => 'ส่ง';

  @override
  String get chatStop => 'หยุด';

  @override
  String get chatClear => 'ล้างแชท';

  @override
  String get chatNewChat => 'แชทใหม่';

  @override
  String get chatRegenerate => 'สร้างใหม่';

  @override
  String get chatEdit => 'แก้ไข';

  @override
  String get chatEditTitle => 'แก้ไขข้อความ';

  @override
  String get chatCopy => 'คัดลอก';

  @override
  String get chatCopied => 'คัดลอกแล้ว';

  @override
  String chatContextLabel(String summary) {
    return 'กำลังสนทนา: $summary';
  }

  @override
  String get chatEmptyGreeting => 'ถามอะไรก็ได้เกี่ยวกับประโยคนี้';

  @override
  String get chatErrorNetwork => 'เครือข่ายไม่พร้อมใช้งาน แตะเพื่อลองใหม่';

  @override
  String get chatErrorGenerate => 'การสร้างล้มเหลว แตะเพื่อลองใหม่';

  @override
  String get chatUpgrade => 'อัปเกรด';

  @override
  String get chatSignInTitle => 'ต้องลงชื่อเข้าใช้';

  @override
  String get chatSignInMessage => 'ลงชื่อเข้าใช้เพื่อใช้ผู้ช่วย AI';

  @override
  String get chatScrollToBottom => 'เลื่อนไปด้านล่าง';

  @override
  String get chatThinking => 'กำลังคิด…';

  @override
  String get chatFollowUp => 'ถาม AI';

  @override
  String get chatFollowUpExplain => 'อธิบาย';

  @override
  String get chatFollowUpTranslate => 'แปล';

  @override
  String get chatFollowUpExample => 'ตัวอย่าง';

  @override
  String get chatFollowUpInstruction =>
      'ตอบคำถามโดยยึดตามข้อความที่อ้างอิงด้านล่างอย่างเคร่งครัด';

  @override
  String get chatQuoteRemove => 'ลบข้อความอ้างอิง';

  @override
  String get retellAiReviewTooltip => 'การตรวจสอบโดย AI';

  @override
  String get retellAiReviewTitle => 'การตรวจสอบการเล่าใหม่โดย AI';

  @override
  String get retellAiReviewKeyPoints => 'การครอบคลุมประเด็นสำคัญ';

  @override
  String get retellAiReviewLabelOriginal => 'ต้นฉบับ';

  @override
  String get retellAiReviewLabelYouSaid => 'คุณพูดว่า';

  @override
  String get retellAiReviewLabelTip => 'เคล็ดลับ';

  @override
  String get retellAiReviewSuggestion => 'ข้อเสนอแนะ';

  @override
  String get retellAiReviewStatusCovered => 'ครอบคลุมแล้ว';

  @override
  String get retellAiReviewStatusPartial => 'บางส่วน';

  @override
  String get retellAiReviewStatusMissed => 'พลาด';

  @override
  String get retellAiReviewStatusDistorted => 'บิดเบือน';

  @override
  String get retellAiReviewStatusAdded => 'เพิ่มเติม';

  @override
  String get retellAiReviewCorrections => 'การแก้ไขสำนวน';

  @override
  String get retellAiReviewCorrectionTypeGrammar => 'ไวยากรณ์';

  @override
  String get retellAiReviewCorrectionTypeWordChoice => 'การเลือกใช้คำ';

  @override
  String get retellAiReviewCorrectionTypeRedundancy => 'คำฟุ่มเฟือย';

  @override
  String get retellAiReviewCorrectionTypePhrasing => 'การเรียบเรียงคำ';

  @override
  String get retellAiReviewCorrectionTypeCohesion => 'ความเชื่อมโยง';

  @override
  String get retellAiReviewEvaluating => 'กำลังประเมิน…';

  @override
  String get retellAiReviewGenerating => 'กำลังสร้าง…';

  @override
  String get retellAiReviewRetry => 'ลองใหม่';

  @override
  String get retellAiReviewError =>
      'การตรวจสอบโดย AI ไม่เสร็จสมบูรณ์ โปรดลองอีกครั้ง';

  @override
  String get retellAiReviewAudioPreparationError =>
      'ไม่สามารถเตรียมการบันทึกเสียงสำหรับการตรวจสอบโดย AI ได้';

  @override
  String get retellAiReviewAudioTooLarge =>
      'การบันทึกเสียงที่เตรียมไว้มีขนาดเกินขีดจำกัด 2 MB';

  @override
  String get retellAiReviewSignInRequiredTitle =>
      'ลงชื่อเข้าใช้เพื่อใช้การตรวจสอบการเล่าใหม่โดย AI';

  @override
  String get retellAiReviewSignInRequiredMessage =>
      'การตรวจสอบการเล่าใหม่โดย AI ใช้บริการ AI บนคลาวด์ ลงชื่อเข้าใช้เพื่อรับข้อเสนอแนะเกี่ยวกับการเล่าใหม่ของคุณ';

  @override
  String get retellAiReviewPlayRecording => 'เล่นการบันทึกเสียง';

  @override
  String get retellAiReviewStopRecording => 'หยุดการบันทึกเสียง';

  @override
  String get videoHideTrack => 'ซ่อนวิดีโอ';

  @override
  String get mediaShowVisualTrack => 'แสดงวิดีโอ';

  @override
  String get mediaEnterFullscreen => 'เต็มหน้าจอ';

  @override
  String get mediaExitFullscreen => 'ออกจากเต็มหน้าจอ';

  @override
  String get mediaHideVideoSubtitles => 'ซ่อนคำบรรยายวิดีโอ';

  @override
  String get mediaShowVideoSubtitles => 'แสดงคำบรรยายวิดีโอ';

  @override
  String get mediaShowSubtitleMask => 'Cover on-screen subtitles';

  @override
  String get mediaHideSubtitleMask => 'Remove subtitle cover';

  @override
  String get mediaSubtitleMaskLabel =>
      'Subtitle cover. Drag to move, pinch or drag an edge handle to resize';

  @override
  String get videoLoopWhole => 'เล่นซ้ำทั้งหมด';

  @override
  String get videoLoopSentence => 'เล่นซ้ำประโยค';

  @override
  String get videoLoading => 'กำลังโหลดวิดีโอ…';

  @override
  String get videoLoadFailed => 'โหลดวิดีโอไม่สำเร็จ';

  @override
  String get videoNoTranscript => 'ไม่มีข้อความถอดเสียง';

  @override
  String get videoRetry => 'ลองอีกครั้ง';

  @override
  String get pronunciationPlay => 'ฟังการออกเสียง';

  @override
  String get collapseSidebar => 'ย่อแถบด้านข้าง';

  @override
  String get expandSidebar => 'ขยายแถบด้านข้าง';

  @override
  String get audioDetailTitle => 'รายละเอียดไฟล์';

  @override
  String get audioDetailDescription => 'คำอธิบาย';

  @override
  String get audioDetailDifficulty => 'ระดับความยาก';

  @override
  String get audioDetailNoDescription => 'ยังไม่มีคำอธิบาย';

  @override
  String learningPlanFromCollection(String collections) {
    return 'จาก $collections';
  }

  @override
  String get profileNickname => 'ชื่อเล่น';

  @override
  String get profileNicknameHint => '1–30 ตัวอักษร';

  @override
  String get profileNicknameEmpty => 'ชื่อเล่นห้ามว่าง';

  @override
  String get profileNicknameTooLong => 'ชื่อเล่นต้องไม่เกิน 30 ตัวอักษร';

  @override
  String get profileNicknameInvalid =>
      'ชื่อเล่นต้องไม่มีอักขระขึ้นบรรทัดใหม่หรืออักขระควบคุม';

  @override
  String get profileSection => 'โปรไฟล์';

  @override
  String get signInSection => 'การเข้าสู่ระบบ';

  @override
  String get profileAvatar => 'รูปโปรไฟล์';

  @override
  String get profileChangeAvatar => 'เปลี่ยนรูปโปรไฟล์';

  @override
  String get profileRemoveAvatar => 'ลบรูปโปรไฟล์';

  @override
  String get profileCropTitle => 'ครอปรูปโปรไฟล์';

  @override
  String get profileSaveFailed => 'บันทึกโปรไฟล์ไม่สำเร็จ โปรดลองอีกครั้ง';

  @override
  String get profileImageUnsupported =>
      'ไม่สามารถใช้รูปนี้ได้ ลองใช้รูป JPEG, PNG หรือ WebP';

  @override
  String get profileLoadFailed => 'โหลดโปรไฟล์ไม่สำเร็จ แตะเพื่อลองอีกครั้ง';

  @override
  String get usageTitle => 'Usage & limits';

  @override
  String get usageEntryTitle => 'This month\'s usage';

  @override
  String get usageEntrySubtitle => 'See progress for each feature';

  @override
  String get usagePlanFree => 'Free plan';

  @override
  String usageMonthlyQuota(String month) {
    return '$month quota';
  }

  @override
  String usageResetsOn(String date) {
    return 'Resets $date';
  }

  @override
  String usagePercentLabel(String percent) {
    return '$percent%';
  }

  @override
  String get usageUnlimited => 'Unlimited';

  @override
  String get usageLoadFailed => 'Couldn\'t load usage. Tap to retry.';

  @override
  String get usageFeatureDictionary => 'AI Lookup';

  @override
  String get usageFeatureTranslate => 'AI Translation';

  @override
  String get usageFeatureAnalyze => 'AI Analysis';

  @override
  String get usageFeatureSenseGroups => 'AI Chunking';

  @override
  String get usageFeatureTranscription => 'AI Transcription';

  @override
  String get usageFeatureChat => 'AI Chat';

  @override
  String get usageFeatureRetellReview => 'AI Retell Review';

  @override
  String get usageFeatureTts => 'AI Text-to-Speech';

  @override
  String get autoShowDailyShareToggle => 'แสดงโมเมนต์วันนี้โดยอัตโนมัติ';

  @override
  String get autoShowDailyShareSubtitle =>
      'แสดงการ์ดของคุณอัตโนมัติเมื่อกลับสู่หน้าเรียนหลังถึงเป้าหมายรายวัน';

  @override
  String get shareCardTitle => 'โมเมนต์วันนี้';

  @override
  String get shareCardPreparing =>
      'กำลังเตรียมการ์ดของคุณ โปรดลองอีกครั้งในอีกสักครู่';

  @override
  String get shareCardPreparationFailed =>
      'เตรียมการ์ดไม่สำเร็จ กำลังลองใหม่ โปรดลองอีกครั้งในอีกสักครู่';

  @override
  String get shareCardNoCards =>
      'ยังไม่มีการ์ดสำหรับแชร์ในขณะนี้ โปรดลองอีกครั้งภายหลัง';

  @override
  String get shareCardNoAlternative => 'ไม่มีการ์ดอื่นให้ใช้';

  @override
  String get shareCardSave => 'บันทึก';

  @override
  String get shareCardSaveDesktop => 'บันทึกรูปภาพ';

  @override
  String get shareCardShare => 'แชร์';

  @override
  String get shareCardChange => 'ลองการ์ดอื่น';

  @override
  String get shareCardSaved => 'บันทึกรูปภาพแล้ว';

  @override
  String get shareCardActionFailed => 'ดำเนินการไม่สำเร็จ โปรดลองอีกครั้ง';

  @override
  String get shareCardPermissionDenied =>
      'อนุญาตการเข้าถึงรูปภาพในการตั้งค่าระบบเพื่อบันทึกการ์ดของคุณ';

  @override
  String get shareCardNotSignedIn => 'เข้าสู่ระบบเพื่อแชร์การ์ดของคุณ';

  @override
  String get favoritesExportMenu => 'Export PDF';

  @override
  String get favoritesExportDialogTitle => 'Export saved items';

  @override
  String favoritesExportSentencesOption(int count) {
    return 'Saved sentences ($count)';
  }

  @override
  String favoritesExportWordsOption(int count) {
    return 'Saved vocabulary ($count)';
  }

  @override
  String get favoritesExportConfirm => 'Export';

  @override
  String get favoritesExportTitle => 'Saved Items';

  @override
  String get favoritesExportSentencesSection => 'Sentences';

  @override
  String get favoritesExportWordsSection => 'Vocabulary';

  @override
  String get favoritesExportUnknownSource => 'Unknown source';

  @override
  String get mediaTrimMenu => 'Trim';

  @override
  String get mediaTrimTitle => 'Trim';

  @override
  String mediaTrimSaveCount(int count) {
    return 'Save ($count)';
  }

  @override
  String get mediaTrimPlay => 'Play (Space)';

  @override
  String get mediaTrimPause => 'Pause (Space)';

  @override
  String get mediaTrimPreviewClip => 'Play clip';

  @override
  String get mediaTrimStopPreview => 'Stop';

  @override
  String get mediaTrimZoomIn => 'Zoom in';

  @override
  String get mediaTrimZoomOut => 'Zoom out';

  @override
  String get mediaTrimZoomFit => 'Show all';

  @override
  String get mediaTrimZoomToClip => 'Zoom to clip';

  @override
  String get mediaTrimHideVideo => 'Hide video';

  @override
  String get mediaTrimShowVideo => 'Show video';

  @override
  String get mediaTrimClips => 'Clips';

  @override
  String get mediaTrimAddClip => 'New clip';

  @override
  String get mediaTrimAddClipTooltip => 'New clip at playhead (N)';

  @override
  String get mediaTrimAutoSplit => 'Auto split';

  @override
  String get mediaTrimEmptyTitle => 'No clips yet';

  @override
  String get mediaTrimEmptyBodySentences =>
      'Tap a sentence to play it and move the playhead there, then tap “New clip”. Drag the ends on the waveform to adjust. “Auto split” cuts everything at once.';

  @override
  String get mediaTrimEmptyBodyFree =>
      'Tap the waveform to move the playhead, then tap “New clip”. “Auto split” cuts everything into equal parts.';

  @override
  String get mediaTrimStart => 'Start';

  @override
  String get mediaTrimEnd => 'End';

  @override
  String get mediaTrimEarlier => 'Earlier';

  @override
  String get mediaTrimLater => 'Later';

  @override
  String get mediaTrimEditTime => 'Enter time';

  @override
  String get mediaTrimRename => 'Rename';

  @override
  String get mediaTrimDelete => 'Delete';

  @override
  String get mediaTrimClipName => 'Clip name';

  @override
  String mediaTrimSentenceCount(int count) {
    return '$count sentences';
  }

  @override
  String get mediaTrimTranscript => 'Transcript';

  @override
  String get mediaTrimTranscriptHint =>
      'Tap a sentence to play it and move the playhead there';

  @override
  String mediaTrimWaveformLoading(int percent) {
    return 'Generating waveform $percent%';
  }

  @override
  String get mediaTrimWaveformFailed => 'Couldn\'t generate the waveform';

  @override
  String get mediaTrimStartTime => 'Start time';

  @override
  String get mediaTrimEndTime => 'End time';

  @override
  String get mediaTrimTimeHint => 'm:ss.mmm, e.g. 1:05.250';

  @override
  String get mediaTrimTimeInvalid => 'Invalid time';

  @override
  String get mediaTrimTimeSnapNote =>
      'The time snaps to the nearest gap between sentences.';

  @override
  String get mediaTrimAutoSplitTitle => 'Auto split';

  @override
  String get mediaTrimAutoSplitTarget => 'Length of each clip';

  @override
  String mediaTrimMinutes(int count) {
    return '$count min';
  }

  @override
  String mediaTrimAutoSplitPreview(int count) {
    return 'Creates $count clips';
  }

  @override
  String get mediaTrimAutoSplitBySentence => 'Cuts only between sentences.';

  @override
  String get mediaTrimAutoSplitEqual => 'Splits into parts of equal length.';

  @override
  String mediaTrimAutoSplitTooShort(int minutes) {
    return 'This item is $minutes min or shorter, so there is nothing to auto split. Tap “New clip” to cut it manually.';
  }

  @override
  String mediaTrimAutoSplitReplace(int count) {
    return 'Replaces the current $count clips.';
  }

  @override
  String get mediaTrimApply => 'Apply';

  @override
  String mediaTrimSaveTitle(int count) {
    return 'Save $count clips';
  }

  @override
  String get mediaTrimSaveTo => 'Save to';

  @override
  String get mediaTrimNewCollection => 'New collection';

  @override
  String get mediaTrimCollectionName => 'Collection name';

  @override
  String mediaTrimDefaultCollectionName(String name) {
    return '$name · Clips';
  }

  @override
  String get mediaTrimNoGapForClip =>
      'Not enough free space for a new clip. Shorten or delete a clip first.';

  @override
  String get mediaTrimSaveLocalOnly =>
      'This item comes from a podcast or shared collection, which is maintained by its source. Clips can only be saved to your own local collections.';

  @override
  String get mediaTrimSaveNote =>
      'The original stays unchanged. Clips are saved together once all of them are ready.';

  @override
  String mediaTrimSaving(int current, int total) {
    return 'Creating clip $current of $total';
  }

  @override
  String get mediaTrimCancelling => 'Cancelling…';

  @override
  String mediaTrimSaved(int count) {
    return 'Saved $count clips';
  }

  @override
  String mediaTrimSavedWithReused(int created, int reused) {
    return 'Saved $created clips. $reused matched existing items and were added to the collection.';
  }

  @override
  String get mediaTrimDiscardTitle => 'Discard these clips?';

  @override
  String get mediaTrimDiscardBody =>
      'Clips that haven\'t been saved will be lost.';

  @override
  String get mediaTrimKeepEditing => 'Keep editing';

  @override
  String get mediaTrimDiscard => 'Discard';

  @override
  String get mediaTrimLoadFailed => 'Couldn\'t open the trim editor';

  @override
  String get mediaTrimFailureSourceMissing =>
      'The media file is missing. Download it first.';

  @override
  String get mediaTrimFailureTranscriptNotReady =>
      'The transcript isn\'t ready yet. Try again later.';

  @override
  String get mediaTrimFailureTranscriptInvalid =>
      'The transcript is invalid. Check it in the subtitle editor first.';

  @override
  String get mediaTrimFailureTranscriptOutOfRange =>
      'Transcript times exceed the media length. Check the transcript first.';

  @override
  String get mediaTrimFailureDuration => 'Couldn\'t read the media length';

  @override
  String get mediaTrimFailureClipTooShort => 'The clip is too short';

  @override
  String get mediaTrimFailureClipOutOfRange => 'The time is outside the media';

  @override
  String get mediaTrimFailureSplitsSentence =>
      'Clips can\'t cut through a sentence';

  @override
  String get mediaTrimFailureNoClips => 'Add a clip first';

  @override
  String get mediaTrimFailureInvalidCollection =>
      'That collection is no longer available. Choose another one.';

  @override
  String get mediaTrimFailureCollectionName => 'Enter a collection name';

  @override
  String get mediaTrimFailureEncode =>
      'Encoding failed. This device may not support the format.';

  @override
  String get mediaTrimFailureOutput =>
      'A clip failed verification. Please try again.';

  @override
  String get mediaTrimFailurePlayback => 'Playback failed';

  @override
  String get mediaTrimFailureCancelled => 'Saving cancelled';

  @override
  String get mediaTrimFailureUnexpected =>
      'Something went wrong. Please try again.';

  @override
  String get audioMenuExport => 'Export';

  @override
  String get audioMenuMoreActions => 'More actions';
}
