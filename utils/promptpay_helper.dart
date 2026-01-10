class PromptPayHelper {
  // ฟังก์ชันสร้าง Payload String ตามมาตรฐาน EMVCo
  static String generatePayload(String target, {double? amount}) {
    // 1. Sanitize Target (Phone or ID Card)
    target = target.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Build Merchant Account Information (Tag 29)
    // ID 29 Structure:
    // 00 (AID) : A000000677010111
    // 01 (Value): 0066812345678 (Phone) OR 0013 + ID (ID Card)

    String merchantInfo = '';
    if (target.length >= 13) {
      // ID Card (13 digits)
      merchantInfo = '0016A0000006770101110213$target';
    } else {
      // Phone Number (Default 08x -> 668x)
      // ตัด 0 ตัวหน้าออกแล้วเติม 66
      if (target.startsWith('0')) {
        target = '66${target.substring(1)}';
      }
      merchantInfo = '0016A000000677010111011300$target';
    }

    String tag29 = '29${_formatLength(merchantInfo)}$merchantInfo';

    String tag53 = '5303764'; // Currency: THB
    String tag58 = '5802TH'; // Country: TH
    String tag54 = ''; // Amount

    if (amount != null) {
      String amtStr = amount.toStringAsFixed(2);
      tag54 = '54${_formatLength(amtStr)}$amtStr';
    }

    // Assemble raw string (without CRC)
    String raw = '000201';
    raw += (amount != null)
        ? '010212'
        : '010211'; // 12=Dynamic(มีเงิน), 11=Static(ไม่มีเงิน)
    raw += tag29;
    raw += tag58;
    raw += tag53;
    if (tag54.isNotEmpty) {
      raw += tag54;
    }
    raw += '6304'; // ID 63 for CRC

    // Calculate CRC
    String crc = _calculateCRC16(raw);
    return raw + crc;
  }

  static String _formatLength(String text) {
    return text.length.toString().padLeft(2, '0');
  }

  // CRC-16/CCITT-FALSE (Polynomial: 0x1021, Initial: 0xFFFF)
  static String _calculateCRC16(String data) {
    int crc = 0xFFFF;
    for (int i = 0; i < data.length; i++) {
      int byte = data.codeUnitAt(i);
      crc ^= (byte << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
      }
    }
    crc &= 0xFFFF;
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
