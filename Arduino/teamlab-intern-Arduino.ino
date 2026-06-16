#include <SPI.h>
#include <MFRC522.h>
#define SS_PIN 10
#define RST_PIN 9
MFRC522 mfrc522(SS_PIN, RST_PIN);

void setup() {
  Serial.begin(9600);
  SPI.begin();
  mfrc522.PCD_Init();
  delay(100);
  Serial.println("RFID ready");
}

String readUID() {
  String uid = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    if (mfrc522.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(mfrc522.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

String uidToMode(String uid) {
  uid.toUpperCase();
  if (uid == "24B30F5B") return "MODE:BLUE";
  if (uid == "C831079E") return "MODE:ICE";
  if (uid == "43731E1D") return "MODE:GREEN";
  return "MODE:UNKNOWN";
}

unsigned long lastSent = 0;
const unsigned long debounceMs = 400;

void loop() {
  if (!mfrc522.PICC_IsNewCardPresent()) return;
  if (!mfrc522.PICC_ReadCardSerial()) return;

  String uid = readUID();
  String mode = uidToMode(uid);

  unsigned long now = millis();
  if (now - lastSent > debounceMs) {
    Serial.println("UID:" + uid);   // デバッグ出力
    Serial.println(mode);           // MODE:BLUE など
    lastSent = now;
  }

  mfrc522.PICC_HaltA();
  delay(50);
}

