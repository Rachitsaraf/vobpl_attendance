import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  bool _isHindi = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          _isHindi ? 'उपस्थिति नियम एवं नीति' : 'Attendance Rules & Policy',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkNavy),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Language Switcher Toggle in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () => setState(() => _isHindi = !_isHindi),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language_rounded, size: 16, color: AppTheme.primaryOrange),
                    const SizedBox(width: 4),
                    Text(
                      _isHindi ? 'English' : 'हिंदी',
                      style: const TextStyle(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isHindi ? 'कंपनी नीति निर्देशिका' : 'Company Policy Guide',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isHindi
                              ? 'अबाध उपस्थिति ट्रैकिंग के लिए कृपया इन दिशानिर्देशों का पालन करें।'
                              : 'Please adhere to these guidelines for seamless attendance tracking.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Rule 1: Geofencing & Location
            _buildRuleCategory(
              icon: Icons.location_on_rounded,
              title: _isHindi
                  ? '1. स्थान और यूनिट परिसर जियोफेंसिंग (50मी गेट / 60मी परिसर)'
                  : '1. Location & Premises Geofencing (50m Gate / 60m Premises)',
              color: AppTheme.accentBlue,
              rules: _isHindi
                  ? [
                      'चेक-इन और चेक-आउट केवल आपकी आवंटित यूनिट परिसर (गेट दिशा में 50मी / परिसर भीतर 60मी) के भीतर ही अनुमत है।',
                      'सुनिश्चित करें कि आपके फ़ोन पर उच्च सटीकता (High Accuracy) GPS हमेशा चालू रहे।',
                      'कम सटीकता वाले सिग्नल (65मी से अधिक त्रुटि) या यूनिट परिसर से बाहर की उपस्थिति को ऐप द्वारा स्वचालित रूप से रोक दिया जाएगा।',
                    ]
                  : [
                      'Check-in & Check-out are allowed within your assigned Unit premises (50m near entrance gate / 60m inside office building).',
                      'Ensure High-Accuracy Location/GPS is turned ON on your phone.',
                      'Low-accuracy cell tower fixes (> 65m error) or attendance outside the unit premises will be automatically blocked by the app.',
                    ],
            ),

            const SizedBox(height: 20),

            // Rule 2: Selfie & Verification
            _buildRuleCategory(
              icon: Icons.camera_alt_rounded,
              title: _isHindi ? '2. सेल्फी और सत्यापन आवश्यकता' : '2. Selfie & Verification Requirement',
              color: AppTheme.successGreen,
              rules: _isHindi
                  ? [
                      'यदि फिंगरप्रिंट/बायोमेट्रिक उपलब्ध नहीं है तो सेल्फी सत्यापन अनिवार्य है।',
                      'सेल्फी फोटो में कर्मचारी का चेहरा उचित रोशनी में स्पष्ट दिखाई देना चाहिए।',
                      'समूह फोटो, फोटो की फोटो, या ढके हुए चेहरे से उपस्थिति अमान्य हो जाएगी।',
                    ]
                  : [
                      'Selfie verification is mandatory if fingerprint/biometrics is unavailable.',
                      'The selfie image must clearly show the employee’s face in proper lighting.',
                      'Group photos, photos of photos, or obstructed faces will invalidate attendance.',
                    ],
            ),

            const SizedBox(height: 20),

            // Rule 3: Leave & Holiday Policy
            _buildRuleCategory(
              icon: Icons.event_available_rounded,
              title: _isHindi ? '3. छुट्टी और अवकाश नीति (Leave Policy)' : '3. Leave & Off Policy',
              color: Colors.purple,
              rules: _isHindi
                  ? [
                      'नियोजित छुट्टी (Planned Leave): कर्मचारियों को उपस्थिति ऐप के माध्यम से कम से कम एक सप्ताह (7 दिन) पहले नियोजित छुट्टी के लिए आवेदन करना होगा।',
                      'आपातकालीन छुट्टी (Emergency Leave): आपात स्थिति के मामले में, कर्मचारी को तुरंत प्रबंधन (Management) को सूचित करना होगा और लागू आपातकालीन प्रक्रिया का पालन करना होगा।',
                      'प्रबंधन को सूचित करना अनिवार्य: किसी भी छुट्टी या अनुपस्थिति के लिए प्रबंधन (Management) को सूचित करना अनिवार्य है। ऐप में आवेदन करने के साथ-साथ प्रबंधन को सीधे/व्यक्तिगत रूप से सूचित करना आवश्यक है।',
                      'केवल ऐप आवेदन अमान्य: प्रबंधन को सीधे/व्यक्तिगत रूप से सूचित किए बिना केवल ऐप के माध्यम से जमा किया गया छुट्टी आवेदन अमान्य माना जाएगा।',
                      'दोनों चरण अनिवार्य हैं: मान्य छुट्टी आवेदन के लिए (1) प्रबंधन को प्रत्यक्ष सूचना और (2) ऐप के माध्यम से छुट्टी आवेदन जमा करना, दोनों आवश्यक हैं।',
                    ]
                  : [
                      'Planned Leave: Employees must apply for planned leave at least one week (7 days) in advance through the attendance application.',
                      'Emergency Leave: In case of an emergency, the employee must immediately inform the management and follow the applicable emergency leave procedure.',
                      'Mandatory Direct Intimation: Informing management is compulsory for any leave or absence. Employees must directly/physically inform management in addition to submitting the leave request through the application.',
                      'App Submission Alone Is Invalid: Simply submitting a leave request through the application without directly/physically informing management will be considered invalid.',
                      'Both Steps Are Mandatory: A valid leave request requires (1) direct/physical intimation to management and (2) submission of the leave request through the application.',
                    ],
            ),

            const SizedBox(height: 20),

            // Rule 4: Offline Syncing
            _buildRuleCategory(
              icon: Icons.wifi_off_rounded,
              title: _isHindi ? '4. ऑफ़लाइन उपस्थिति और सिंक' : '4. Offline Attendance & Syncing',
              color: Colors.blueGrey,
              rules: _isHindi
                  ? [
                      'कम नेटवर्क वाले क्षेत्रों में, उपस्थिति आपके डिवाइस पर स्थानीय रूप से सुरक्षित हो जाती है।',
                      'इंटरनेट से जुड़ते ही स्थानीय रिकॉर्ड स्वचालित रूप से सर्वर पर सिंक हो जाएंगे।',
                      'रिपोर्टिंग विसंगतियों से बचने के लिए सुनिश्चित करें कि ऑफ़लाइन रिकॉर्ड 24 घंटे के भीतर सिंक हो जाएं।',
                    ]
                  : [
                      'In low-network zones, attendance is saved locally on your device.',
                      'Connecting to the internet will automatically sync local records to the server.',
                      'Ensure offline records are synced within 24 hours to avoid reporting discrepancies.',
                    ],
            ),

            const SizedBox(height: 32),

            // Contact HR Footer
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_outline_rounded, color: AppTheme.primaryOrange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isHindi
                          ? 'कोई प्रश्न है? एचआर (HR) विभाग से संपर्क करें'
                          : 'Have questions? Contact HR Department',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkNavy.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCategory({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> rules,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkNavy.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Column(
            children: rules.map((rule) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rule,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.darkNavy.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
