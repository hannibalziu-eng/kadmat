import 'package:go_router/go_router.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../navigation/app_routes.dart';

List<GoRoute> getWalletRoutes() {
  return [
    GoRoute(
      path: AppRoutes.wallet,
      builder: (context, state) => const WalletScreen(),
    ),
  ];
}
