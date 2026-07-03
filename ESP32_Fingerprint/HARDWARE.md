# S.Mart POS - ESP32 Fingerprint Reader Hardware Guide
# คู่มือการจัดเตรียมฮาร์ดแวร์ระบบแสกนลายนิ้วมือ ESP32 - S.Mart POS

Version: 5.0 (Updated: JST-XH Modular Connections / SCL=GPIO22 / Buzzer=GPIO18 / Button=GPIO33)
เวอร์ชัน: 5.0 (อัปเดต: การเชื่อมต่อโมดูลาร์ด้วยปลั๊ก JST-XH / ขา SCL=GPIO22 / ลำโพง=GPIO18 / ปุ่มกด=GPIO33)

---

## 📌 JST-XH Modular Pin Mapping / ตารางพิกัดขั้วต่อปลั๊ก JST-XH

To make assembly and repair extremely easy, we use **JST-XH 2.54mm connectors** soldered directly to the perfboard (บอร์ดเขียวไข่ปลา). Below is the precise pinout sequence for crimping the female housings and soldering the male headers.

เพื่อช่วยให้การประกอบและการส่งซ่อมง่ายที่สุด เราจะใช้ **เต้ารับปลั๊ก JST-XH ขนาด 2.54 มม.** บัดกรีลงบอร์ดเขียวไข่ปลาโดยตรง ด้านล่างนี้คือลำดับคู่สายสำหรับประกอบหัวสายตัวเมียและบัดกรีเต้าตัวผู้บนบอร์ด

### 🖥️ 1. LCD 2004 + I2C Interface (4-Pin JST-XH)
| Pin (JST) | Function / หน้าที่ | ESP32 Connection / ต่อเข้าขา | Recommended Wire Color / สีสายไฟแนะนำ |
| :---: | :--- | :--- | :--- |
| **1** | **VCC** (Power 5V) | ➡️ Rail **VIN (5V)** | ⚪ White / ขาว |
| **2** | **GND** (Ground) | ➡️ Rail **GND** | ⚫ Black / ดำ |
| **3** | **SDA** (Data) | ➡️ **GPIO 21 (D21)** | 🔴 Red / แดง |
| **4** | **SCL** (Clock) | ➡️ **GPIO 22 (D22)** | 🔴 Red / แดง |

---

### 🕵️ 2. R307S Fingerprint Scanner (6-Pin JST-XH)
*Note: Make sure to wire RX to TX and TX to RX.*
*หมายเหตุ: ต้องแน่ใจว่าได้ต่อไขว้สาย RX เข้า TX และ TX เข้า RX*

| Pin (JST) | Sensor Pin / ขาตัวเซนเซอร์ | ESP32 Connection / ต่อเข้าขา | Recommended Wire Color / สีสายไฟแนะนำ |
| :---: | :--- | :--- | :--- |
| **1** | **VCC** (5V Sensor Power) | ➡️ Rail **VIN (5V)** | 🔴 Red / แดง |
| **2** | **GND** (Ground) | ➡️ Rail **GND** | ⚫ Black / ดำ |
| **3** | **TXD** (Transmit Data) | ➡️ **GPIO 16 (RX2)** | 🟡 Yellow / เหลือง |
| **4** | **RXD** (Receive Data) | ➡️ **GPIO 17 (TX2)** | 🟢 Green / เขียว |
| **5** | **Touch Out** (Finger Sense) | ➡️ **GPIO 4 (D4)** | 🔵 Blue / น้ำเงิน |
| **6** | **Touch 3.3V** (Touch Power) | ➡️ Rail **3.3V** | ⚪ White / ขาว |

---

### 🔊 3. Active Buzzer Module (3-Pin JST-XH)
*Connected to 3.3V instead of 5V to prevent accidental false buzzing.*
*ต่อไฟเลี้ยงที่ 3.3V แทน 5V เพื่อป้องกันเสียงกระตุกหรือลั่นเอง*

| Pin (JST) | Module Pin / ขาโมดูล | ESP32 Connection / ต่อเข้าขา | Recommended Wire Color / สีสายไฟแนะนำ |
| :---: | :--- | :--- | :--- |
| **1** | **VCC / +** (Power 3.3V) | ➡️ Rail **3.3V** | ⚪ White / ขาว |
| **2** | **GND / -** (Ground) | ➡️ Rail **GND** | ⚫ Black / ดำ |
| **3** | **I/O / S** (Signal) | ➡️ **GPIO 18 (D18)** | 🔴 Red / แดง |

---

### 🔴 4. Mode Selection Button (3-Pin JST-XH)
| Pin (JST) | Module Pin / ขาโมดูล | ESP32 Connection / ต่อเข้าขา | Recommended Wire Color / สีสายไฟแนะนำ |
| :---: | :--- | :--- | :--- |
| **1** | **VCC** (Power 3.3V) | ➡️ Rail **3.3V** | ⚪ White / ขาว |
| **2** | **OUT / S** (Signal Output) | ➡️ **GPIO 33 (D33)** | 🔴 Red / แดง |
| **3** | **GND** (Ground) | ➡️ Rail **GND** | ⚫ Black / ดำ |

---

## 🛠️ DIY JST-XH Crimping & Assembly Guide / คู่มือการเข้าหัวสายและประกอบปลั๊ก JST-XH

Since you have a DIY kit that requires manual assembly, follow these steps to secure the wires without a professional crimping tool.

เนื่องจากชุดคิทของพี่ติเป็นแบบประกอบเอง หากไม่มีคีมย้ำสายไฟเฉพาะทาง สามารถทำตามขั้นตอนด้านล่างนี้ได้โดยใช้คีมปากจิ้งจกและเครื่องบัดกรีครับ

### 🎞️ Step-by-Step Instructions / ขั้นตอนการทำทีละขั้น

```
 Carrier Strip (แถบยึดโรงงาน)
   |===|======|======|
       |      |
      [ ]    [ ] <-- Cut individual terminal pin here / ตัดพินตรงนี้แยกออกเป็นชิ้นเดี่ยว
      ( )    ( )
      / \    / \ <-- Insulation Wings (ปีกคู่บน: บีบเปลือกสายไฟ) **Red Arrow
     |   |  |   |
      \ /    \ / <-- Conductor Wings (ปีกคู่ล่าง: บีบลวดทองแดง)
      | |    | |
      |_|    |_| <-- Contact Nose (เบ้าเสียบปลายสุด)
```

#### 1. Cut the Terminal / ตัดหัวเหล็กตัวเมีย
- Cut or twist the individual metal terminal away from the flat metal carrier strip at the top.
- ตัดหรือบิดตัวพินเหล็กตัวเมียแยกออกจากแถบยึดโรงงานด้านบนสุดให้เรียบร้อย

#### 2. Strip the Wires / ปอกเปลือกสายไฟ
- Strip only **1.5 to 2 mm** of insulation from the end of the wire. Do not make it too long.
- ปอกเปลือกฉนวนพลาสติกที่ปลายสายไฟออกเพียง **1.5 - 2 มม.** เท่านั้น อย่าปอกยาวเกินไป

#### 3. Squeeze with Pliers / หนีบยึดด้วยคีม
- Lay the wire inside the terminal: the bare copper wire must sit inside the **lower wings**, and the plastic insulation must sit inside the **upper wings** (indicated by red arrows in the picture).
- Squeeze both sets of wings firmly using needle-nose pliers (คีมปากแหลม) until they wrap and clamp the wire tightly. The wire should be mechanically locked and not slip out.
- วางสายไฟลงบนพินเหล็ก: ให้ทองแดงเปลือยพาดอยู่ตรง **ปีกคู่ล่าง** และให้เปลือกพลาสติกพาดอยู่ตรง **ปีกคู่บน (ที่ลูกศรแดงชี้)**
- ใช้คีมหนีบปีกเหล็กทั้งสองชุดเข้าหากันให้แน่นหนาจนบีบรัดตัวสายไฟและฉนวนพลาสติกอยู่หมัดขยับไม่ได้

#### 4. Apply Solder / บัดกรีเพิ่มความแข็งแรง (แนะนำอย่างยิ่ง)
- Use a soldering iron to apply a **tiny drop of solder** directly onto the bare copper wire inside the lower wings.
- **CAUTION:** Do not let the solder flow down into the contact nose (bottom socket), otherwise it will block the male pin from entering.
- ใช้หัวแร้งแตะตะกั่วบัดกรี **หยดเล็กๆ** ลงไปเชื่อมระหว่างทองแดงกับพินเหล็ก
- **ข้อควรระวัง:** ห้ามให้ตะกั่วบัดกรีไหลลงไปอุดตรงรูกล่องสี่เหลี่ยมด้านล่างสุด (Contact Nose) เพราะจะทำให้เสียบเข้ากับขาเหล็กตัวผู้ไม่ได้

#### 5. Insert into Plastic Housing / เสียบเข้าบล็อกพลาสติก
- Locate the **small metal spring tab (เงี่ยงล็อคโลหะ)** on the flat side of the terminal.
- Align it with the side of the white plastic housing that has small rectangular windows.
- Push the terminal straight into the back of the housing until you feel a soft **"click"**.
- หันด้านที่มี **เงี่ยงตัวล็อคโลหะแบนๆ** บนพินเหล็กให้ตรงกับด้านที่มีช่องเจาะเล็กๆ บนบล็อกพลาสติกสีขาว
- ดันพินสอดเข้าไปจากรูท้ายบล็อกจนได้ยินเสียง **"คลิก"** เบาๆ ลองดึงสายดู หากไม่หลุดแสดงว่าใช้งานได้แล้วครับ

---

## 🗺️ Perfboard 5x7 cm Layout (Component Side) / ผังจัดวางอุปกรณ์บนบอร์ดเขียว 5x7 ซม. (ด้านบนบอร์ด)

Using JST-XH male ports means we solder the male sockets (Straight Pin Headers in plastic shroud) directly on the board. The layout becomes even cleaner:

การใช้ปลั๊ก JST-XH ตัวผู้บัดกรีลงบอร์ด จะช่วยให้ด้านหน้าบอร์ดสะอาดและจัดสรรพื้นที่ได้ดียิ่งขึ้นดังนี้ครับ:

```
      +-------------------------------------------------------+
      | 1   2   3   4   5   6   7   8   9  10  11  12  13  14 15 | <-- Column (รูแนวตั้ง)
    A | [G] [G] [G] [G] [G] [G] [G] [G] [G] [G] [G] [G] [G] [G] | <-- Row A: Rail GND (รางดิน)
    B |   |====== Female Socket Left (ตัวเมียฝั่งซ้าย) ======|   | (1x15 Pin Header)
    C |   | [EN]  [D36] [D39] [D34] [D35]  |                  |
    D |   | [D32] [D33] [D25] [D26] [D27]  |                  |
    E |   | [D14] [D12] [D13] [GND] [5V]   |                  |
    F |   |================================|                  |
    G |                                                       |
    H |            [  ESP32 DevKit V1 30-Pin  ]               | (Mounted in middle / เสียบคร่อมกลาง)
    I |                                                       |
    J |   |================================|                  |
    K |   |====== Female Socket Right (ตัวเมียฝั่งขวา) =====|   | (1x15 Pin Header)
    L |   | [D23] [D22] [TXD] [RXD] [D21]  |                  |
    M |   | [D19] [D18] [D5]  [TX2] [RX2]  |                  |
    N |   | [D4]  [3V3] [RST] [GND] [VIN]  |                  |
    O |   |================================|                  |
    P |                                                       |
    Q | [3.3V] [3.3V] [3.3V] [3.3V] [3.3V]                    | <-- Row Q: Rail 3.3V
    R |                                                       |
    S | [5V] [5V] [5V] [5V] [5V] [5V] [5V]                    | <-- Row S: Rail 5V (VIN)
    T |                                                       |
    U | [JST-XH 4P]  VCC  GND  SDA  SCL  (พอร์ตสำหรับ LCD 2004)  | (Solder male header directly)
    V | [JST-XH 6P]  VCC  GND  TXD  RXD  TCH  3V3 (แสกน R307S) | (Solder male header directly)
    W | [JST-XH 3P]  VCC  GND  I/O   (พอร์ตสำหรับ Active Buzzer)| (Solder male header directly)
    X | [JST-XH 3P]  VCC  OUT  GND   (พอร์ตสำหรับ ปุ่มกดแมนนวล)  | (Solder male header directly)
      +-------------------------------------------------------+
```

* **Under-board wiring rule:** Solder copper rails under rows A, Q, and S for power distribution. Run thin insulated wires underneath the board from each JST-XH solder pad to the corresponding ESP32 female header pin.
* **การเดินลายปริ้นท์ใต้บอร์ด:** ทำรางตะกั่วส่งไฟบนแถว A (GND), Q (3.3V) และ S (5V) จากนั้นใช้ลวดทองแดงมีฉนวน ลากเดินใต้บอร์ดข้ามไปยังพินเต้ารับตัวเมียของ ESP32 ตามขาที่ระบุในตารางพอร์ต JST ด้านบนครับ
