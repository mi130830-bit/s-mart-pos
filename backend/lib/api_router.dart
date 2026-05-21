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
import 'package:shelf/shelf.dart';
import 'middlewares/jwt_middleware.dart';

class ApiRouter {
  Router get router {
    final router = Router();

    final securedPipeline = Pipeline().addMiddleware(jwtMiddleware());

    // Mount AuthController at /auth (Public)
    router.mount('/auth', AuthController().router.call);

    // Mount HealthController at /health (Public)
    router.mount('/health', HealthController().router.call);

    // Public Routes for Webhooks and Desktop POS (No Firebase JWT)
    router.mount('/line', LineController().router.call);
    router.mount('/payment', PaymentController().router.call);

    // Secured Routes (Requires Firebase JWT from S-Link)
    router.mount('/products', securedPipeline.addHandler(ProductController().router.call));
    router.mount('/customers', securedPipeline.addHandler(CustomerController().router.call));
    router.mount('/orders', securedPipeline.addHandler(OrderController().router.call));
    router.mount('/stock', securedPipeline.addHandler(StockController().router.call));
    router.mount('/shortages', securedPipeline.addHandler(ShortageController().router.call));
    router.mount('/debt', securedPipeline.addHandler(DebtController().router.call));
    router.mount('/jobs', securedPipeline.addHandler(JobController().router.call));
    router.mount('/rewards', securedPipeline.addHandler(RewardController().router.call));

    return router;
  }
}
