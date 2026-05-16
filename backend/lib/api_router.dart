import 'package:shelf_router/shelf_router.dart';
import 'controllers/auth_controller.dart';
import 'controllers/product_controller.dart';
import 'controllers/order_controller.dart';
import 'controllers/line_controller.dart';
import 'controllers/payment_controller.dart';
import 'controllers/stock_controller.dart';
import 'controllers/customer_controller.dart';
import 'controllers/shortage_controller.dart';
import 'controllers/health_controller.dart';
import 'controllers/debt_controller.dart';
import 'controllers/job_controller.dart';
import 'controllers/reward_controller.dart';

class ApiRouter {
  Router get router {
    final router = Router();

    // Mount AuthController at /auth
    router.mount('/auth', AuthController().router.call);

    // Mount ProductController at /products
    router.mount('/products', ProductController().router.call);

    // Mount CustomerController at /customers
    router.mount('/customers', CustomerController().router.call);

    // Mount OrderController at /orders
    router.mount('/orders', OrderController().router.call);

    // Mount LineController at /line
    router.mount('/line', LineController().router.call);

    // Mount PaymentController at /payment
    router.mount('/payment', PaymentController().router.call);

    // Mount StockController at /stock
    router.mount('/stock', StockController().router.call);

    // Mount ShortageController at /shortages
    router.mount('/shortages', ShortageController().router.call);

    // Mount HealthController at /health
    router.mount('/health', HealthController().router.call);

    // Mount DebtController at /debt
    router.mount('/debt', DebtController().router.call);

    // Mount JobController at /jobs — รับแจ้งจาก S-Link เมื่อส่งของเสร็จ
    router.mount('/jobs', JobController().router.call);

    // Mount RewardController at /rewards
    router.mount('/rewards', RewardController().router.call);

    return router;
  }
}
