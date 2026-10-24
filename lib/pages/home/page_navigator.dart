// ... existing code ...
import 'package:campus_app/pages/wallet/wallet_page.dart';
import 'package:campus_app/pages/more/more_page.dart';
import 'package:campus_app/pages/home/widgets/page_navigation_animation.dart';
import 'package:campus_app/pages/navigation/outdoor_navigation_page.dart';
import 'package:campus_app/screens/curatorial_screen.dart';

enum PageItem { feed, events, coupons, curatorial, navigation, mensa, wallet, more }

class PageNavigatorRoutes {
// ... existing code ...
      case PageItem.mensa:
        rootPage = MensaPage(
          mainNavigatorKey: mainNavigatorKey,
          pageEntryAnimationKey: pageEntryAnimationKey,
          pageExitAnimationKey: pageExitAnimationKey,
        );
        break;
      case PageItem.curatorial:
        rootPage = const CuratorialScreen(); 
        break;
      case PageItem.navigation:
        rootPage = NavigationPage(
          pageEntryAnimationKey: pageEntryAnimationKey,
          pageExitAnimationKey: pageExitAnimationKey,
        );
        break;
// ... existing code ...
