# 📖 คู่มือการใช้งานระบบ POS Desktop (User Manual)

เอกสารฉบับนี้รวบรวมวิธีการใช้งานระบบ POS Desktop อย่างละเอียด โดยแบ่งตามหมวดหมู่การใช้งานจริง เพื่อให้ผู้ใช้งานสามารถทำความเข้าใจและใช้งานระบบได้อย่างมีประสิทธิภาพสูงสุด

---

## 1. หน้าจอหลักและการเข้าระบบ (Dashboard & Auth)

### 🔐 การเข้าระบบ (Login System)

**[TH]**
- **ข้อมูลที่ใช้เข้าสู่ระบบ:** ใช้ "ชื่อผู้ใช้" (Username) และ "รหัสผ่าน" (Password) 
- **ระบบจดจำรหัสผ่าน (Remember Me):** มีระบบจดจำรหัสผ่าน โดยหากติ๊กเลือก จะมีการบันทึก Username และ Password ไว้ในระบบ (ผ่าน SharedPreferences) เพื่อให้ไม่ต้องพิมพ์ใหม่ในครั้งถัดไป
- **การทำงานเบื้องหลัง:** ระบบจะพยายามล็อกอินผ่าน API (คลาวด์) เป็นหลัก หากไม่มีอินเทอร์เน็ต ระบบจะสลับไปตรวจสอบรหัสผ่านกับฐานข้อมูลในเครื่อง (Local MySQL) ทันที ทำให้หน้าร้านสามารถเปิดบิลได้แม้เน็ตหลุด และเมื่อเข้าสู่ระบบสำเร็จ ระบบจะทำการล็อกอินเข้า Firebase ให้อัตโนมัติ (สำหรับฟีเจอร์ Sync ของ S-Link)

**[EN]**
- **Credentials:** Requires "Username" and "Password".
- **Remember Me:** Supported. If checked, the system securely saves the username and password locally (via SharedPreferences) for future auto-fill.
- **Behind the Scenes:** The system primarily authenticates via the Cloud API. In offline scenarios, it automatically falls back to the Local DB (MySQL) for authentication, ensuring uninterrupted POS operations. It also auto-authenticates with Firebase upon success to support mobile sync features.

### 🛡️ สิทธิ์การใช้งาน (Roles & Permissions)

**[TH]**
- **ระดับผู้ใช้งานหลัก (Roles):** แบ่งเป็น `ADMIN` (ผู้ดูแลระบบ) และพนักงานทั่วไป (User)
- **การทำงานของสิทธิ์ (Permission Structure):**
  - **ADMIN:** เป็น Superuser หากระบบตรวจพบว่าเป็น ADMIN จะให้สิทธิ์ในการเข้าถึงทุกเมนูและทุกฟังก์ชันอัตโนมัติ (Override everything)
  - **พนักงาน (User):** จะต้องถูกกำหนดสิทธิ์รายบุคคลแบบแยกย่อย (Granular Permissions) เช่น สิทธิ์ในการดูต้นทุน (`canViewCostPrice`), สิทธิ์ในการดูกำไร (`canViewProfit`), หรือสิทธิ์ในการดูแท็บต่างๆ ในหน้า Dashboard (เช่น `dashboard_view_summary`) ซึ่งข้อมูลสิทธิ์จะโหลดจาก API หรือฐานข้อมูลในเครื่องตอนล็อกอิน

**[EN]**
- **Roles:** The main roles are `ADMIN` and standard `USER`.
- **Permission Structure:**
  - **ADMIN:** Acts as a superuser. The system grants full access to all features and menus automatically, overriding specific permission checks.
  - **Standard Users:** Controlled via granular, key-based permissions defined per user (e.g., `canViewCostPrice`, `canViewProfit`, `dashboard_view_summary`). Permissions are loaded dynamically from the API or local database during login.

### 📊 หน้าจอหลัก (Dashboard)

**[TH]**
หน้าจอหลักจะถูกแบ่งออกเป็น 5 แท็บ ซึ่งพนักงานแต่ละคนจะเห็นแท็บแตกต่างกันตามสิทธิ์ที่ได้รับ:
1. **แท็บ "รายการวันนี้" (Today's Orders):** แท็บพื้นฐานที่ทุกคนเห็น ใช้แสดงตารางบิลรายการขายของวันนี้ มีช่องค้นหาบิลอัจฉริยะ (ค้นได้จากเลขบิล, ชื่อ หรือเบอร์โทร), มีปุ่มออกรายงานส่งของ (Export ส่งของ) และปุ่ม "ปิดกะ (Close Shift)"
2. **แท็บ "สรุปยอดขาย" (Sales Summary):** (ต้องการสิทธิ์ `dashboard_view_summary`) ประกอบด้วย วิดเจ็ตการ์ดสรุปยอดขายวันนี้, จำนวนบิล, กำไรขั้นต้น, ปุ่มดูรายงานสรุปน้ำมัน, กราฟแสดงสถิติยอดขายรายชั่วโมง, ตารางสรุปยอดขายเชื่อ (หนี้ค้างรับ), และส่วนสรุปเปรียบเทียบยอดขายรายเดือน/รายปี
3. **แท็บ "สรุปบัญชีการเงิน" (Financial Report):** (ต้องการสิทธิ์ `dashboard_view_trend`) สรุปเส้นทางการเงินของร้าน
4. **แท็บ "วิเคราะห์ AI" (AI Analysis):** (ต้องการสิทธิ์ `dashboard_view_ai`) สำหรับให้ AI ช่วยวิเคราะห์แนวโน้มธุรกิจ
5. **แท็บ "สินค้าขายดี" (Best Selling):** (ต้องการสิทธิ์ `dashboard_view_best_selling`) จัดอันดับสินค้าขายดีของร้าน
- **แหล่งที่มาข้อมูล:** วิดเจ็ตและกราฟต่างๆ ดึงข้อมูลมาจาก `dashboardProvider` ซึ่งรวบรวมข้อมูลผ่าน `MySQLService` (ดึงประวัติบิล), `ApiService` และ `OrderRepository` โหลดผลลัพธ์แบบ Asynchronous เพื่อไม่ให้หน้าจอกระตุก

**[EN]**
The Dashboard consists of up to 5 tabs, conditionally visible based on the user's permissions:
1. **"Today's Orders" Tab (DashboardDailyTab):** The default view containing a data table of the day's sales, a smart search bar (by bill number, customer name, phone), an "Export Logistics" button, and a "Close Shift" button.
2. **"Sales Summary" Tab (DashboardSummaryTab):** (Requires `dashboard_view_summary`) Features stat cards (Today's Sales, Orders Count, Gross Profit), a "Fuel Summary" button, hourly sales charts, a credit/unpaid debt summary table, and a period selector for Month/Year comparisons.
3. **"Financial Report" Tab:** (Requires `dashboard_view_trend`) Embedded financial trends and accounting logic.
4. **"AI Analysis" Tab:** (Requires `dashboard_view_ai`) AI-driven business insights.
5. **"Best Selling" Tab:** (Requires `dashboard_view_best_selling`) Top-selling product rankings.
- **Data Source:** Widgets consume data from the `dashboardProvider` state controller, which fetches and aggregates information asynchronously via `MySQLService` (local logs), `ApiService`, and `OrderRepository` to ensure smooth UI performance.

---

## 2. หน้าขายสินค้า (POS Checkout)

### 🛒 การเพิ่มสินค้าลงบิล (Adding Items to Cart)

**[TH]**
*   **การสแกนบาร์โค้ด (Barcode Scanning):** รองรับการใช้เครื่องสแกนบาร์โค้ดยิงบาร์โค้ดได้ทันที โดยระบบมีฟังก์ชันดักจับแป้นพิมพ์อัตโนมัติ (Focus ตลอดเวลา) และมาพร้อมระบบแปลงภาษาไทยอัตโนมัติ (กรณีพนักงานลืมเปลี่ยนภาษาที่คีย์บอร์ด)
*   **การค้นหาสินค้า (Product Search):** กดปุ่ม **F3** บนคีย์บอร์ด เพื่อเปิดหน้าต่างค้นหาสินค้าด้วยชื่อหรือรหัส หรือกด **F4** (Quick Menu) เพื่อเลือกสินค้าด่วนที่ไม่มีบาร์โค้ด
*   **สินค้าชั่งน้ำหนัก (Weighing Products):** หากสแกนสินค้าที่เป็นประเภทชั่งน้ำหนัก ระบบจะเด้งหน้าต่าง (Dialog) ขึ้นมาให้ระบุน้ำหนักเป็นกิโลกรัมทันที

**[EN]**
*   **Barcode Scanning:** Supports instant barcode scanning with an auto-focus listener. It also features automatic Thai layout correction in case the user forgets to switch the keyboard language.
*   **Product Search:** Press **F3** to open the product search dialog by name or SKU, or press **F4** (Quick Menu) for fast access to non-barcode items.
*   **Weighing Products:** When scanning a weighing product, a dialog will automatically pop up to prompt for the weight in kilograms.

### 📝 การปรับแก้บิล (Modifying the Bill)

**[TH]**
*   **การแก้ไขจำนวน (Adjusting Quantity):** กด **F1** เพื่อระบุจำนวนสินค้าที่จะสแกนล่วงหน้า (เช่น "10" แล้วสแกนบาร์โค้ด) หรือคลิกที่ตัวสินค้าในบิลเพื่อแก้ไขจำนวน
*   **การใส่ส่วนลด (Applying Discounts):** 
    *   **ส่วนลดรายชิ้น:** คลิกที่สินค้าแล้วเลือกแก้ส่วนลด (รองรับทั้งแบบ % หรือจำนวนเงิน) 
    *   **ส่วนลดท้ายบิล:** กดที่ช่อง "ส่วนลด 2 (เพิ่มเติม)" ตรงแผงสรุปยอดด้านขวาเพื่อกรอกส่วนลดพิเศษท้ายบิล 
*   **การลบสินค้า (Removing Items):** ลบรายชิ้นโดยการกดปุ่มลบในรายการ (มีการเช็คสิทธิ์พนักงาน: void_item) หรือกด **F5** เพื่อล้างบิลและเริ่มต้นใหม่ทั้งหมด

**[EN]**
*   **Adjusting Quantity:** Press **F1** to set a pre-quantity before scanning (e.g., set "10" then scan), or simply click on the item in the cart list to adjust its quantity.
*   **Applying Discounts:**
    *   **Per-item Discount:** Click on the item and adjust the discount (supports both flat amount and percentage).
    *   **Bill Discount:** Click on the "Extra Discount 2" box on the right summary panel to apply a manual discount to the total bill.
*   **Removing Items:** Remove individual items via the delete button on the list (requires 'void_item' permission), or press **F5** to clear the entire cart and start over.

### 💳 ระบบชำระเงิน (Payment System)

**[TH]**
*   **ช่องทางการชำระเงิน (Payment Methods):** รองรับ 4 ช่องทางหลัก ได้แก่ เงินสด (Cash), สแกน QR/โอนเงิน (QR/Transfer), บัตรเครดิต (Credit Card), และเงินเชื่อ (Credit)
*   **การคำนวณเงินทอน (Change Calculation):** เมื่อเข้าสู่หน้าชำระเงิน (กด **F9**) ระบบจะคำนวณเงินทอนให้อัตโนมัติ หากระบุยอดรับเงินสดเกินกว่าราคาสุทธิ (มีปุ่ม Spacebar ช่วยเติมยอดคงเหลือให้เต็มรวดเร็ว)
*   **ฟีเจอร์เพิ่มเติม (Additional Features):** มีระบบตรวจสอบสลิปโอนเงิน (Slip Verification), สามารถใช้คะแนนสะสมและคูปองเป็นส่วนลดได้ในหน้าต่างชำระเงิน, เลือกว่าจะพิมพ์/ไม่พิมพ์ใบเสร็จได้

**[EN]**
*   **Payment Methods:** Supports 4 main methods: Cash, QR/Transfer, Credit Card, and Credit (Store Credit).
*   **Change Calculation:** Upon pressing **F9** to checkout, the system calculates the change automatically if the received cash exceeds the grand total (Pressing Spacebar auto-fills the remaining exact amount).
*   **Additional Features:** Includes Slip Verification logic, point redemption and coupon discount capabilities directly in the payment modal. Option to toggle receipt printing on/off.

### 💻 การทำงานร่วมกับอุปกรณ์ภายนอก (Hardware Integration)

**[TH]**
*   **จอแสดงผลฝั่งลูกค้า (Customer Display):** รองรับเต็มรูปแบบ มีการอัปเดตรายการสินค้า ยอดรวม เงินทอน และสามารถแสดงผล QR Code ชำระเงินให้ลูกค้าสแกนได้โดยตรง
*   **ลิ้นชักเก็บเงิน (Cash Drawer):** มีคำสั่งสั่งเปิดลิ้นชัก (เตะลิ้นชัก) ผ่าน ReceiptService อัตโนมัติเมื่อทำรายการชำระเงินสำเร็จ
*   **เครื่องชั่งน้ำหนักดิจิทัล (Digital Scale):** *หมายเหตุ (แผนในอนาคต):* ปัจจุบันพนักงานต้องพิมพ์ตัวเลขน้ำหนักเองผ่านหน้าต่าง (Manual) แต่มีแผนงานที่จะดึงค่าจาก Serial COM Port อัตโนมัติ (อยู่ใน Roadmap)
- **Keyboard Shortcuts (ปุ่มลัด):** 
  - `F1`: เปลี่ยนจำนวนสินค้า (Change Quantity)
  - `F2`: เลือกลูกค้า (Select Customer)
  - `F3`: ค้นหาสินค้า (Search Product)
  - `F4`: เมนูลัด (Quick Menu)
  - `F5`: ยกเลิกบิล (Reset Transaction)
  - `F9`: ชำระเงิน (Payment)
  - `ESC`: ล้างช่องสแกนบาร์โค้ด (Clear Barcode Input)

**[EN]**
*   **Customer Display:** Fully supported. Automatically updates the item list, total amount, change, and can push the payment QR Code directly to the secondary display.
*   **Cash Drawer:** Automatically sends a cash drawer kick command via the ReceiptService upon successful transaction.
*   **Digital Scale:** *Note (Roadmap):* Currently requires manual input via a dialog, but automated weight reading via Serial COM Port is planned for the future.

---

## 3. สินค้าและคลัง (Products & Stock)

หมวดหมู่นี้ครอบคลุมการจัดการฐานข้อมูลสินค้า การตั้งราคา โปรโมชัน การนับสต็อก และการพิมพ์บาร์โค้ด

### 3.1 การจัดการสินค้า (Product Management)
การเพิ่มหรือแก้ไขสินค้าจะทำผ่านหน้าต่าง **Product Form** ซึ่งประกอบด้วย:
- **ข้อมูลทั่วไป (General Info):** บาร์โค้ด (Barcode), ชื่อสินค้า (Name), ชื่อย่อ (Alias), รูปภาพ (Image URL)
- **การจัดหมวดหมู่ (Categorization):** ประเภทสินค้า (ทั่วไป/ชั่งน้ำหนัก), หมวดหมู่ (Category), หน่วยนับ (Unit), ผู้จำหน่าย (Supplier), และกำหนดว่าเป็นสินค้ามีสต็อกหรือไม่ (Warehouse Item)
- **ระบบราคา (Pricing):** รองรับราคาทั้งแบบปลีก (Retail) และส่ง (Wholesale) รวมไปถึงราคาสมาชิก (Member Prices) อีกทั้งยังสามารถตั้งค่าภาษี (VAT) และอนุญาตให้พนักงานแก้ไขราคาหน้าจอขายได้
- **การจัดการคลัง (Stock Management):** ยอดคงเหลือ (Stock Quantity), เปิดการติดตามสต็อก (Track Stock), จุดสั่งซื้อ (Reorder Point), จุดสต็อกล้น (Overstock Point), จำกัดจำนวนซื้อ (Purchase Limit), วันหมดอายุ (Expiry Date)

**การตั้งค่าขั้นสูง (Advanced Settings):**
- **ราคาหลายระดับ (Price Tiers):** ตั้งราคาตามขั้นบันได เช่น ซื้อ 10 ชิ้น ราคาลดลง
- **ส่วนประกอบสินค้า (Linkage/Components):** สำหรับสินค้าแบบจัดชุด (Composite) ที่ต้องตัดสต็อกชิ้นส่วนย่อย

### 3.2 การจัดการคลัง (Stock Management)
- **การตรวจนับและปรับยอดสต็อก (Stock Check & Adjustment):**
  - **ทำรายการเช็ค (Check Stock):** สามารถเพิ่มรายการสินค้าย่อยทีละรายการ หรือ **"ดึงใบงาน S_MartPOS" (Cloud Import)** จากแอปมือถือลงมาเพื่อเช็คสต็อกหน้าร้านได้ และกดบันทึกยืนยันพร้อมกันทั้งหมด
  - **ประวัติการเช็ค (History):** สามารถเรียกดูประวัติการปรับยอดสต็อกย้อนหลังได้
- **การรับสินค้าเข้า (Stock In):**
  - จัดการใบสั่งซื้อ (Purchase Orders) และกดรับสินค้าเข้าคลัง ซึ่งยอดสต็อกจะถูกอัปเดตอัตโนมัติ และบันทึกประวัติไว้ในแท็บประวัติรับเข้า

### 3.3 ระบบพิมพ์บาร์โค้ด (Barcode Printing)
- หน้าจอจะแบ่งเป็นสองฝั่ง (ค้นหาสินค้า และ คิวการพิมพ์)
- สามารถปรับจำนวนดวงสติ๊กเกอร์ที่ต้องการพิมพ์สำหรับสินค้าแต่ละชิ้นได้อย่างอิสระ
- เลือกลักษณะ **แนวการพิมพ์ (Orientation)** ได้ทั้งแนวนอน (Landscape) และแนวตั้ง (Portrait)

### 3.4 ระบบแจ้งเตือนสินค้าใกล้หมด (Low Stock Alerts)
- ระบบจะตรวจสอบสต็อกอัตโนมัติทุกๆ 30 วินาที
- หากสินค้าใดยอดคงเหลือน้อยกว่าหรือเท่ากับ **จุดสั่งซื้อ (Reorder Point)** สินค้านั้นจะถูกนำมาแสดงในหน้าแจ้งเตือน
- **ความสามารถพิเศษ:** ระบบมีฟังก์ชัน **แนะนำผู้จำหน่ายที่ราคาถูกที่สุด (Cheapest Supplier Suggestions)** อัตโนมัติ! และมีการติดตามสถานะการสั่งซื้อ (Open, Ordered, Received, Done) เพื่อกันการสั่งซ้ำซ้อน

---

## 3. Products & Stock (English Version)

This module covers database management, pricing, promotions, inventory counting, and barcode printing.

### 3.1 Product Management
Adding or editing products is done via the **Product Form** dialog:
- **General Info:** Barcode, Name, Alias, Image URL.
- **Categorization:** Product Type (General/Weighing), Category, Unit, Supplier, and Warehouse Item flag.
- **Pricing:** Supports Retail, Wholesale, and Member-specific prices. Also handles VAT settings and allows price editing at checkout.
- **Stock Management:** Stock Quantity, Track Stock toggle, Reorder Point, Overstock Point, Purchase Limit, and Expiry Date.

**Advanced Settings:**
- **Price Tiers:** Set step-pricing (e.g., Buy X at price Y).
- **Linkage/Components:** For composite products that deduce stock from sub-components.

### 3.2 Stock Management
- **Stock Check & Adjustment:**
  - **Check Stock:** Add individual items or use **"Cloud Import"** to pull worksheet data from the S_MartPOS mobile app. Confirm all counts in one click.
  - **History:** View past stock adjustment logs.
- **Stock In:**
  - Manage Purchase Orders and receive inventory. Stock levels are automatically updated and recorded in the Received History tab.

### 3.3 Barcode Printing
- The screen is divided into two sections (Search and Print Queue).
- You can freely adjust the number of sticker labels needed for each item.
- Supports both **Landscape** and **Portrait** print orientations.

### 3.4 Low Stock Alerts (Shortage Provider)
- The system automatically polls stock levels every 30 seconds.
- Products with stock equal to or below their **Reorder Point** will appear in the alert list.
- **Special Feature:** Automatically offers **Cheapest Supplier Suggestions** for missing items! It also tracks order statuses (Open, Ordered, Received, Done) to prevent double ordering.

---

## 4. ระบบลูกค้าร้าน (Customers & CRM)

หมวดหมู่นี้ครอบคลุมการจัดการฐานข้อมูลลูกค้า ระบบสมาชิก การสะสมแต้ม และการบริหารลูกหนี้

### 4.1 การจัดการข้อมูลลูกค้า (Customer Management)
สามารถจัดการข้อมูลลูกค้าผ่านหน้าต่าง **Customer Form** โดยแบ่งกลุ่มข้อมูลได้ดังนี้:
- **ข้อมูลส่วนตัวและสมาชิก:** รหัสสมาชิก (ตั้งเองหรือสุ่มอัตโนมัติ), ระดับสมาชิก (Tier), ชื่อ, นามสกุล, เบอร์โทรศัพท์, วันเกิด, และวันหมดอายุของสมาชิก
- **ข้อมูลสำหรับภาษีและเอกสาร:** เลขประจำตัวประชาชน, เลขประจำตัวผู้เสียภาษี (Tax ID), ที่อยู่ตามบัตรประชาชน, และที่อยู่สำหรับจัดส่งสินค้า
- **ข้อมูลการขนส่ง (Logistics):** ระยะทางจัดส่งตั้งต้น (เป็นระยะทางไป-กลับกิโลเมตร) 
  - **พิเศษ:** มีปุ่มกดเพื่อดึงระยะทางจากประวัติรายงานการขนส่งที่เคยไปส่งมาลงอัตโนมัติได้ทันที
- **อื่นๆ:** ช่องหมายเหตุ (Remarks)

### 4.2 ระดับสมาชิก (Member Tiers)
ระบบมีการแบ่งระดับของลูกค้า (Tier) ทั้งหมด 4 ระดับ ซึ่งส่งผลต่อระดับราคาสินค้า, ส่วนลด และตัวคูณแต้มสะสม:
1. **ทั่วไป (General):** ซื้อสินค้าใน "ราคาขายปลีก" (Retail), ไม่มีส่วนลดพิเศษ, สะสมแต้มคูณ 1.0
2. **Silver:** ซื้อสินค้าใน "ราคาขายสมาชิก" (Member)
3. **Gold:** ซื้อสินค้าใน "ราคาขายสมาชิก" (Member), ได้รับส่วนลดพิเศษ 5%, **สะสมแต้มคูณ 1.5 เท่า**
4. **Platinum:** ซื้อสินค้าใน "ราคาขายส่ง" (Wholesale), ได้รับส่วนลดพิเศษ 10%, **สะสมแต้มคูณ 2.0 เท่า**

### 4.3 ระบบลูกหนี้และการชำระเงิน (Debtor / Credit System)
- หน้าต่างเฉพาะสำหรับลูกหนี้ สามารถดูประวัติการเป็นหนี้ (Ledger), ดูบิลที่ค้างชำระ, และทำรายการรับชำระหนี้ได้
- มีปุ่ม "คำนวณยอดหนี้ใหม่" (Recalculate) ให้กดใช้งานในกรณีที่พบว่าข้อมูลยอดหนี้ไม่ตรงกับความเป็นจริง
- ระบบรองรับการออกใบวางบิล (Billing Notes)

### 4.4 ฟีเจอร์เพิ่มเติม (Additional Features)
- **ระบบเชื่อมต่อ Line Official (Line CRM):** หน้าโปรไฟล์ลูกค้าจะแสดงสถานะการเชื่อมต่อกับ Line OA ของร้าน (มีรูปโปรไฟล์และชื่อ Line) และมีปุ่ม "Unlink" เพื่อยกเลิกการเชื่อมต่อ
- **ระบบสะสมแต้ม (Point Ledger):**
  - แต้มสะสมมีการบันทึกพร้อมวันหมดอายุ (Expires)
  - แอดมินสามารถใช้เมนู "ล้างคะแนนสะสม" (Reset Points) เพื่อเคลียร์แต้มลูกค้าทุกคนได้ (ต้องยืนยันด้วย PIN)
- **การค้นหาลูกค้า:** ค้นหาได้จาก "ชื่อ" หรือ "เบอร์โทรศัพท์" โดยรายชื่อจะแสดง ยอดหนี้ค้างชำระ (สีแดง), แต้มสะสมปัจจุบัน, และระยะทางจัดส่ง ให้เห็นทันที
- **Import CSV:** สามารถนำเข้าข้อมูลลูกค้าใหม่ทั้งหมดจากไฟล์ Excel (CSV) ได้

---

## 4. Customers & CRM (English Version)

This module covers customer database management, membership tiers, loyalty points, and debtor management.

### 4.1 Customer Management
Customer information is managed through the **Customer Form**, which includes:
- **Personal & Membership Info:** Member ID (manual or auto-generated), Member Tier, Name, Phone Number, Birthday, and Membership Expiry Date.
- **Tax & Billing Info:** National ID, Tax ID, Billing Address, and Shipping Address.
- **Logistics Info:** Default delivery distance (round-trip in kilometers).
  - **Special Feature:** Automatically pulls delivery distance from past delivery reports with one click.
- **Others:** Remarks field for internal notes.

### 4.2 Membership Tiers
The system defines 4 customer tiers that automatically affect price levels, discounts, and point multipliers:
1. **General:** "Retail" price level, no special discounts, 1.0x point multiplier.
2. **Silver:** "Member" price level.
3. **Gold:** "Member" price level, 5% special discount, **1.5x point multiplier**.
4. **Platinum:** "Wholesale" price level, 10% special discount, **2.0x point multiplier**.

### 4.3 Debtor / Credit System
- Dedicated debtor screen to view the credit ledger, outstanding bills, and receive debt payments.
- Features a "Recalculate" button to fix out-of-sync debt balances.
- Supports generating Billing Notes.

### 4.4 Additional Features
- **Line Official Integration (Line CRM):** The customer profile displays their linked Line OA status, profile picture, and Line display name. Includes an "Unlink" button.
- **Point Ledger:**
  - Loyalty points are tracked with expiry dates.
  - Admins can use the "Reset Points" menu to clear all customer points (requires Admin PIN).
- **Customer Search:** Search by "Name" or "Phone Number". The result list instantly displays outstanding debt (in red), current points, and delivery distance.
- **Import CSV:** Bulk import customer data via CSV file.

---

## 5. ระบบซัพพลายเออร์และการสั่งซื้อ (Suppliers & Purchase Orders)
**[TH]**
ระบบนี้ออกแบบมาเพื่อจัดการตัวแทนจำหน่ายและสร้างใบสั่งซื้อ (PO) เพื่อนำสินค้าเข้าคลังอย่างเป็นระบบ:
*   **การจัดการข้อมูลซัพพลายเออร์ (Supplier Management):** 
    *   สามารถเพิ่ม/แก้ไขข้อมูลผ่านหน้าเมนู "ซัพพลายเออร์" (จำเป็นต้องระบุชื่อ) 
    *   รองรับการบันทึก เบอร์โทรศัพท์, ที่อยู่, ชื่อเซลล์, และ LINE ID ของเซลล์ เพื่อความสะดวกในการติดต่อ
    *   ระบบค้นหารองรับการหาจาก "ชื่อ" และ "เบอร์โทรศัพท์"
*   **การสร้างใบสั่งซื้อ (Create Purchase Order):**
    *   สามารถสร้างใบสั่งซื้อโดยเลือกซัพพลายเออร์ และเพิ่มรายการสินค้าที่ต้องการสั่ง
    *   รองรับการระบุจำนวนและราคาต้นทุน (Cost Price) ระบบจะคำนวณยอดรวมให้อัตโนมัติด้วยความแม่นยำสูง
    *   สามารถสั่งพิมพ์ใบสั่งซื้อเป็นเอกสาร PDF เพื่อส่งให้เซลล์ได้
*   **การรับสินค้าเข้าคลัง (Receive Stock):**
    *   ใบสั่งซื้อมีสถานะเช่น ร่าง (DRAFT), สั่งซื้อแล้ว (ORDERED), รับของแล้ว (RECEIVED)
    *   เมื่อสินค้ามาส่งจริง สามารถเปิดดูรายละเอียด PO และกด **"รับสินค้าเข้าคลัง (Receive Stock)"** ระบบจะนำสินค้าเติมเข้าสต็อกและเปลี่ยนสถานะ PO ทันที

**[EN]**
This system is designed to manage suppliers and generate Purchase Orders (POs) for systematic stock intake:
*   **Supplier Management:**
    *   Add/Edit suppliers through the "Suppliers" menu (Name is required).
    *   Supports saving Phone, Address, Salesperson Name, and Salesperson LINE ID for easy contact.
    *   Search function supports searching by Name and Phone Number.
*   **Create Purchase Order:**
    *   Create a PO by selecting a supplier and adding items.
    *   Specify quantities and cost prices; the system automatically calculates the exact total.
    *   POs can be printed as PDF documents to send to sales representatives.
*   **Receive Stock:**
    *   POs track statuses such as DRAFT, ORDERED, and RECEIVED.
    *   Upon delivery, open the PO details and click **"Receive Stock"**. The system will automatically add the items to inventory and update the PO status.

---

## 6. ระบบทรัพยากรบุคคลและการลงเวลา (HR & Payroll)
**[TH]**
ระบบจัดการพนักงาน สแกนลายนิ้วมือ และการคำนวณเงินเดือนอัตโนมัติ:
*   **การจัดการพนักงาน (Employee Management):**
    *   กำหนดสิทธิ์ (Roles) เช่น ADMIN, REQUESTER, DRIVER, GAS_STATION, HR
    *   บันทึกข้อมูลส่วนตัว (ชื่อ, เบอร์โทร, ตำแหน่ง) และเชื่อมโยงกับบัญชีผู้ใช้ในแอป S-Link
    *   กำหนดรูปแบบการจ้าง (รายเดือน/รายวัน), รอบจ่ายเงิน, เงินเดือน, และค่าเที่ยว (Trip Rate)
*   **ระบบสแกนลายนิ้วมือ (Fingerprint Setup):**
    *   เชื่อมต่อผ่าน WiFi/LAN (ค่าเริ่มต้น `fingerprint.local`)
    *   รองรับพนักงานสูงสุด 31 คน (ใช้คนละ 4 Slots)
    *   **การลงทะเบียนนิ้ว:** สแกนนิ้วเดียวกัน 3 มุม (ตรง, ซ้าย, ขวา) มุมละ 2 ครั้ง รวม 6 ครั้งต่อ 1 คน
    *   เมื่อแตะนิ้วเพื่อเข้า/ออกงาน ระบบจะดึงข้อมูลอัปเดตสถานะบน Dashboard ทันที
    *   *กรณีฉุกเฉิน:* มีฟังก์ชัน "ปิดร้านฉุกเฉิน" (Emergency Close Shop) เพื่อบังคับ Clock Out พนักงานทุกคน (ต้องใช้ PIN ผู้ดูแล)
*   **ระบบการจ่ายเงินเดือน (Salary & Expenses):**
    *   สามารถกรองพนักงานตามรอบจ่ายเงินและช่วงเวลาที่ต้องการ เพื่อคำนวณเงินเดือนและค่าเที่ยวได้อัตโนมัติ
    *   เมื่อตรวจสอบความถูกต้องแล้ว สามารถกดยืนยัน **"ลงรายจ่าย"** ระบบจะบันทึกรายจ่ายลงสมุดบัญชีร้านทันที และเปลี่ยนสถานะบิลเป็น PAID

**[EN]**
A complete system for managing employees, fingerprint attendance, and automated payroll calculation:
*   **Employee Management:**
    *   Assign Roles (ADMIN, REQUESTER, DRIVER, GAS_STATION, HR).
    *   Save personal details (name, phone, position) and link with S-Link user accounts.
    *   Set wage types (Monthly/Daily), pay cycles, base salary, and trip rates.
*   **Fingerprint Setup:**
    *   Connects via WiFi/LAN (default: `fingerprint.local`).
    *   Supports up to 31 employees (4 memory slots per person).
    *   **Enrollment Process:** Scan the same finger at 3 angles (Center, Left, Right) twice per angle (6 scans total).
    *   Clock in/out instantly updates the dashboard in real-time.
    *   *Emergency:* An "Emergency Close Shop" function allows admins to force clock out all active employees (Admin PIN required).
*   **Payroll & Expenses:**
    *   Filter employees by pay cycle and date range to automatically calculate salaries and trip commissions.
    *   After verifying the totals, click **"Save to Expenses"**. The system will log this as an official expense and mark the payroll record as PAID.

---

## 7. ระบบขนส่งและการออกรายงาน (Logistics & Reports)
**[TH]**
ระบบจัดการงานจัดส่งสินค้าไปยังลูกค้า (รองรับการทำงานร่วมกับ S-Link Mobile) และการสรุปรายงาน:
*   **การสร้างและติดตามงานจัดส่ง:**
    *   เมื่อชำระเงินที่หน้า POS และเลือกรับบริการส่งของ ระบบจะสร้างงาน (Delivery Job) อัตโนมัติ พร้อมส่งแจ้งเตือน Telegram (ถึงแอดมิน) และ LINE OA (แจ้งลูกค้าว่า "กำลังเตรียมสินค้า")
    *   งานจะถูกส่งขึ้นคลาวด์เพื่อให้คนขับรถที่มีแอป S-Link เข้ามารับงานและอัปเดตสถานะ (เช่น กำลังจัดส่ง, จัดส่งสำเร็จ)
    *   **การคำนวณระยะทาง:** ระบบจะดึงพิกัดถนนจริง (OSRM) เพื่อคำนวณระยะทางไป-กลับ และตีเป็นค่าใช้จ่ายอัตโนมัติ (หากออฟไลน์จะสลับไปใช้สูตร Haversine สำรอง)
*   **การออกรายงาน (Reports):**
    *   **ติดตามงานส่ง (Delivery Dashboard):** ดูภาพรวมและแผนที่พิกัดลูกค้าในแต่ละวัน
    *   **รายงานขนส่ง (Delivery Report):** ค้นหาประวัติการขนส่งย้อนหลัง พร้อมฟังก์ชัน **"Export Excel"** ที่สามารถสรุปยอดรายวันและแยก Sheet ตามคันรถได้
*   **การจัดการข้อมูล (Cleanup & Archiving):**
    *   เพื่ิอประหยัดค่าใช้จ่ายคลาวด์ เมื่อการจัดส่งเสร็จสิ้นสมบูรณ์ ระบบจะดูดประวัติกลับมาเก็บไว้ในคอมพิวเตอร์ที่ร้าน (MySQL) แบบถาวร และลบข้อมูลออกจาก Firebase (Cloud) โดยอัตโนมัติ

**[EN]**
A logistics management system synchronized with the S-Link mobile app, along with comprehensive reporting:
*   **Delivery Jobs & Tracking:**
    *   Upon checkout at the POS with delivery selected, the system auto-generates a delivery job. It triggers a Telegram alert (to admins) and a LINE OA message (notifying the customer).
    *   Jobs are synced to the cloud, allowing drivers using the S-Link app to accept them and update real-time statuses (e.g., shipping, completed).
    *   **Distance Calculation:** Utilizes OSRM for precise round-trip road distance calculation (with a Haversine formula fallback if offline).
*   **Reports:**
    *   **Delivery Dashboard:** A daily overview of all active logistics operations and customer coordinate mapping.
    *   **Delivery Report:** Search past delivery histories and utilize the **"Export Excel"** function to generate multi-sheet reports separated by delivery vehicles.
*   **Data Cleanup & Archiving:**
    *   To optimize cloud costs, once a delivery is marked as "Completed," the system archives the record into the local MySQL database and automatically deletes the job payload from Firebase.

---

## 8. ประวัติการขายและการจัดการบิล (Sales History & Order Management)

**[TH]**
ประวัติการขายทั้งหมดสามารถดูได้จากแท็บ "รายการวันนี้" และ "สรุปยอดขาย" บนหน้า Dashboard หลัก โดยระบบจะแสดงบิลที่สร้างขึ้นทั้งหมดในวันที่เลือก พร้อมฟังก์ชันจัดการบิลย้อนหลังดังนี้:

*   **ฟังก์ชันที่ทำได้กับบิลแต่ละใบ:**
    *   👁️ **ดูรายละเอียด (View Details):** เปิดดูรายการสินค้าทั้งหมดในบิลนั้น
    *   🖨️ **ปริ้นซ้ำ (Reprint):** สั่งพิมพ์ใบเสร็จหรือใบกำกับภาษีของบิลนั้นใหม่ได้ทันที
    *   💵 **เปลี่ยนสถานะยังไม่จ่าย (Mark Unpaid):** แปลงบิลที่ชำระแล้วกลับเป็นสถานะเงินเชื่อ (เฉพาะสิทธิ์ Admin)
    *   🚚 **ส่งของ (Send to Delivery):** สร้างงานจัดส่งย้อนหลังสำหรับบิลที่ยังไม่ได้ส่ง
    *   📦 **แจ้งรับของหลังร้าน (Send to Back Shop):** แยกสินค้าบางรายการให้พนักงานหลังร้านไปหยิบ
    *   ❌ **ยกเลิกบิล (Void):** ยกเลิกบิลและคืนสต็อกสินค้าทั้งหมดในบิล (เฉพาะสิทธิ์ Admin และต้องใส่รหัสผ่านยืนยัน)
    *   👤 **เปลี่ยนลูกค้า (Change Customer):** แก้ไขข้อมูลลูกค้าบนบิลที่ยังไม่ถูกยกเลิก
*   **ข้อควรรู้:** เพื่อป้องกันระบบค้าง การดึงรายการบิลย้อนหลังจะถูกจำกัดที่ครั้งละ 500 รายการ (Pagination) หากต้องการดูข้อมูลมากกว่านั้น ให้เลือกช่วงวันที่ที่แคบลง

**[EN]**
All sales history is accessible from the "Today's Orders" and "Sales Summary" tabs on the main Dashboard. The system displays all invoices for the selected date with the following order management functions:

*   **Available Actions per Order:**
    *   👁️ **View Details:** Inspect all line items within a specific invoice.
    *   🖨️ **Reprint:** Instantly reprint any receipt or tax invoice for a past order.
    *   💵 **Mark Unpaid:** Convert a paid invoice back to credit status (Admin permission required).
    *   🚚 **Send to Delivery:** Create a retrospective delivery job for any undelivered order.
    *   📦 **Send to Back Shop:** Flag items for staff to retrieve from the back warehouse.
    *   ❌ **Void (Cancel Order):** Cancel the invoice and fully restore all stock quantities (Admin + password confirmation required).
    *   👤 **Change Customer:** Re-assign a customer to an active, non-voided invoice.
*   **Note:** To prevent memory crashes, order history is paginated at 500 records per fetch. Narrow the date range if you need a specific period.

---

## 9. การตั้งค่าระบบ (System Settings)

**[TH]**
เข้าถึงได้จากเมนู "ตั้งค่า" ทางด้านซ้าย ซึ่งรวบรวมการตั้งค่าทั้งหมด 14 หมวดหมู่ไว้ในที่เดียว:

*   **⚙️ ทั่วไป (General):** ตั้งชื่อร้าน, เปิด/ปิด VAT, ตั้งค่าการพิมพ์ใบกำกับภาษี (ใบสั้น/ใบเต็ม)
*   **🖨️ เครื่องพิมพ์ (Printer Settings):** กำหนดเครื่องพิมพ์สำหรับสลิปความร้อน 80mm, ใบ A4/A5 และบาร์โค้ด โดยเชื่อมต่อกับ Windows Print Driver โดยตรง
*   **🌐 การเชื่อมต่อ (Connection Settings):** ศูนย์กลางการตั้งค่าการเชื่อมต่อทั้งหมด:
    *   **LINE OA:** ใส่ Channel Access Token สำหรับส่งสลิปอิเล็กทรอนิกส์ให้ลูกค้า
    *   **Telegram Bot:** ใส่ Bot Token และ Chat ID สำหรับรับแจ้งเตือนสำคัญ (เช่น ยอดขายประจำวัน, แจ้งเตือนสต็อกหมด)
    *   **Firebase, AI (Gemini), GPS:** ตั้งค่า API Keys สำหรับบริการคลาวด์ต่างๆ
    *   ⚠️ **ข้อสำคัญด้านความปลอดภัย:** ทุกช่องที่เป็น Token หรือ API Key จะถูกซ่อนเป็น ******* โดยอัตโนมัติ เพื่อป้องกันไม่ให้คนที่เดินผ่านมองเห็นได้
*   **🔒 ระบบและความปลอดภัย (System & Security):** จัดการสิทธิ์ (Require Admin Password), ล้างข้อมูล (Factory Reset), หรือจัดการ Database

**[EN]**
Accessible from the left-side "Settings" menu, which consolidates all 14 configuration categories:

*   **⚙️ General:** Configure shop name, VAT settings, and tax invoice printing preferences (short/full form).
*   **🖨️ Printer Settings:** Map printers for 80mm thermal receipts, A4/A5 documents, and barcode labels, integrating directly with Windows print drivers.
*   **🌐 Connection Settings:** The central hub for all external integrations:
    *   **LINE OA:** Enter the Channel Access Token to enable electronic slip delivery to customers.
    *   **Telegram Bot:** Configure the Bot Token and Chat ID for critical alerts (e.g., daily sales, low stock warnings).
    *   **Firebase, AI (Gemini), GPS:** Set API Keys for various cloud services.
    *   ⚠️ **Security Note:** All Token and API Key fields are automatically masked (****) to prevent visual exposure to bystanders.
*   **🔒 System & Security:** Manage permissions (Admin Password requirements), perform a Factory Reset, or manage database operations.

---

## 10. ระบบอัปเดตอัตโนมัติ (Auto Updater)

**[TH]**
ระบบอัปเดตถูกออกแบบให้ผู้ใช้ควบคุมได้เต็มที่ ไม่มีการอัปเดตแอบเงียบๆ:

1.  **วิธีเช็คอัปเดต:** กดปุ่มรูปไอคอน "Update" (⬇️) ที่มุมล่างซ้ายของเมนูหลัก
2.  **การทำงาน:** ระบบจะตรวจสอบเวอร์ชันล่าสุดจาก GitHub (`appcast.xml`) หากพบเวอร์ชันใหม่จะแสดงหน้าต่างยืนยันการอัปเดต
3.  **ข้อสำคัญ (Windows UAC):** หากได้ติดตั้งแอปไว้ใน `C:\Program Files` จำเป็นต้องปิดแอปและเปิดใหม่ โดย **"คลิกขวาที่ไอคอนแอป > Run as Administrator"** ก่อนที่จะกดอัปเดต มิฉะนั้น Windows จะบล็อกการเขียนทับไฟล์และอัปเดตไม่สำเร็จ ระบบจะแจ้งเตือนให้ทำขั้นตอนนี้ก่อนโดยอัตโนมัติ

**[EN]**
The update system is designed for full user control — no silent background updates:

1.  **How to Check for Updates:** Click the "Update" icon (⬇️) at the bottom-left of the main navigation menu.
2.  **How it Works:** The system fetches the latest version info from GitHub (`appcast.xml`). If a newer version is found, a confirmation dialog will appear.
3.  **Important (Windows UAC):** If the app is installed in `C:\Program Files`, you must first close the app and relaunch it by **right-clicking the app icon > "Run as Administrator"** before pressing update. Otherwise, Windows will block the file overwrite and the update will fail. The system will automatically prompt you with this reminder before downloading.

---

*(เอกสารฉบับนี้ครบสมบูรณ์แล้ว — Version 1.0 | อัปเดตล่าสุด: กรกฎาคม 2026)*
