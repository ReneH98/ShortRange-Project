/*
    Tutorial: https://randomnerdtutorials.com/esp32-bluetooth-low-energy-ble-arduino-ide/
    UUIDs: // https://www.uuidgenerator.net/
*/

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#include <Arduino.h>
#include "MHZ19.h"
#include <Adafruit_SSD1306.h>
#include <analogWrite.h>
#include "DHT.h"
#include "sensors.h"

unsigned long showDataTimer = 0;
unsigned long warnTimer = -1000 * 60 * 5;

// SSD1306 display
#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 32 // OLED display height, in pixels
#define OLED_RESET     -1 // Reset pin # (or -1 if sharing Arduino reset pin)
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

bool turnON = false;
bool CO2warningFlag = false;

// Service UUIDs
#define SERVICE_UUID        "3b13b75a-fc06-11eb-9a03-0242ac130003"

// Characteristic UUIDs
#define TEMP_UUID           "1488d73e-cb63-4f24-b03a-0b0a8bc390ff"
#define HUM_UUID            "bafab626-fa6e-451d-9278-3f77dcd65ee1"
#define CO2_UUID            "d7d2905a-1233-11ec-82a8-0242ac130003"

#define BLE_NAME "SmartHome_airquality"

BLEServer *pServer;
BLEService *pService;

// new characteristics
BLECharacteristic *pTempChar;
BLECharacteristic *pHumChar;
BLECharacteristic *pCO2Char;

// one minute each
const int publish_time_temp = 1000 * 60; 
const int publish_time_hum = 1000 * 60;
const int publish_time_CO2 = 1000 * 60;

long last_time_published_temp = 0;
long last_time_published_hum = 0;
long last_time_published_CO2 = 0;

// states
bool deviceConnected = false;
bool oldDeviceConnected = false;
const int DEFAULT_WAIT = 1;

void publishData(float value, BLECharacteristic *bleChar);

class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onRead(BLECharacteristic *pCharacteristic) {
      Serial.print("onRead");
    }
};

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("device connected");
        
      // send temp
      publishData(temp, pTempChar);
      tempBuffer = temp;

      // send hum
      publishData(humidity, pHumChar);
      humidityBuffer = humidity;
      
      // send co2
      publishData(CO2, pCO2Char);
      CO2Buffer = CO2;
    }

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("device disconnected");
    }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Starting SmartHome_airquality Sensor!");
  randomSeed(millis());

  /*
     init Sensors
  */
  touchAttachInterrupt(TOUCH, touch_callback, TOUCH_THRESHOLD);

  // LEDs
  pinMode(LED_R, OUTPUT);
  pinMode(LED_G, OUTPUT);
  pinMode(LED_B, OUTPUT);
  analogWrite(LED_R, 0);
  analogWrite(LED_G, 255);
  analogWrite(LED_B, 0);

  // temp and humidity
  dht.begin();

  // display setup
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { // Address 0x3D for 128x64
    Serial.println(F("SSD1306 allocation failed"));
    analogWrite(LED_R, 255);
    analogWrite(LED_G, 0);
    while (1);
  }
  display.display();
  delay(500);
  display.clearDisplay();
  display.display();
  display.setTextSize(1);
  display.setTextColor(WHITE);

  // mhz setup
  Serial.println("Start MH-Z19 setup...");
  Serial2.begin(MHZ19_BAUDRATE, MHZ19_PROTOCOL, RX_PIN, TX_PIN);
  mhz19.begin(Serial2);
  char mhz19_version[4];
  mhz19.getVersion(mhz19_version);
  Serial.print("--------------------\nMH-Z19 Firmware Version: ");
  for (int i = 0; i < 4; i++) {
    Serial.print(mhz19_version[i]);
    if (i == 1)
      Serial.print(".");
  }
  Serial.print("\nMH-Z19B Messbereich: ");
  Serial.println(mhz19.getRange());

  mhz19.autoCalibration(false);
  Serial.print("MH-Z19B Autokalibrierung (ABC): ");
  mhz19.getABC() ? Serial.println("AN") :  Serial.println("AUS");
  printMHZ19infos();
  Serial.println("--------------------");
  Serial.println("Preheat...");
  display.setCursor(0, 0);
  display.setTextSize(2);
  display.print("Preheat...");
  display.display();
  delay(1000 * PREHEAT_SECONDS);
  display.setTextSize(1);

  analogWrite(LED_R, 0);
  analogWrite(LED_G, 0);
  analogWrite(LED_B, 0);
  display.clearDisplay();
  display.display();

  /*
     init Bluetooth
  */
  // init server
  Serial.println(BLE_NAME);
  BLEDevice::init(BLE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  pService = pServer->createService(SERVICE_UUID);
  Serial.println("Server init done");

  // init sensor characteristics
  pTempChar = pService->createCharacteristic(TEMP_UUID, BLECharacteristic::PROPERTY_READ);
  pTempChar->setCallbacks(new MyCharacteristicCallbacks());

  pHumChar = pService->createCharacteristic(HUM_UUID, BLECharacteristic::PROPERTY_READ);
  pHumChar->setCallbacks(new MyCharacteristicCallbacks());

  pCO2Char = pService->createCharacteristic(CO2_UUID, BLECharacteristic::PROPERTY_READ);
  pCO2Char->setCallbacks(new MyCharacteristicCallbacks());

  // init descriptors
  BLEDescriptor *pDescriptorTemp = new BLEDescriptor((uint16_t)0x2901);
  pTempChar->addDescriptor(pDescriptorTemp);
  pDescriptorTemp->setValue("Temperature [°C]");

  BLEDescriptor *pDescriptorHum = new BLEDescriptor((uint16_t)0x2901);
  pHumChar->addDescriptor(pDescriptorHum);
  pDescriptorHum->setValue("Humidity [%]");

  BLEDescriptor *pDescriptorCO2 = new BLEDescriptor((uint16_t)0x2901);
  pCO2Char->addDescriptor(pDescriptorCO2);
  pDescriptorCO2->setValue("Air Quality [CO2]");

  pService->start();
  Serial.println("Service start");
  // BLEAdvertising *pAdvertising = pServer->getAdvertising();  // this still is working for backward compatibility

  // Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("Characteristic defined! Now you can read it in your phone!");
}

void loop() {
  getEnvData();
  if (turnON) {
    printEnvData();
    interpretData();

    if (millis() - showDataTimer >= 5000) {
      analogWrite(LED_R, 0);
      analogWrite(LED_G, 0);
      analogWrite(LED_B, 0);
      display.clearDisplay();
      display.display();
      turnON = false;
    }
  }

  if (deviceConnected) {

    /*
     * force publishing because of threshold
     */
      
     if (forcePublish_co2) {
        publishData(CO2, pCO2Char);
        Serial.print("Force Sent co2: "); Serial.println(CO2);
        forcePublish_co2 = false;
        CO2Buffer = CO2;
     }

     if (forcePublish_temp) {
        publishData(temp, pTempChar);
        Serial.print("Force Sent temp: "); Serial.println(temp);
        forcePublish_temp = false;
        tempBuffer = temp;
     }

     if (forcePublish_hum) {
        publishData(humidity, pHumChar);
        Serial.print("Force Sent humidity: "); Serial.println(humidity);
        forcePublish_hum = false;
        humidityBuffer = humidity;
     }

    /*
     * regular publishing during time period
     */
     
    if (millis() - last_time_published_temp >= publish_time_temp) {
      last_time_published_temp = millis();
      if(publish_temp) {
        publishData(temp, pTempChar);
        Serial.print("Sent temp: "); Serial.println(temp);
        publish_temp = false;
        tempBuffer = temp;
      }
    }

    if (millis() - last_time_published_hum >= publish_time_hum) {
      last_time_published_hum = millis();
      if(publish_hum) {
        publishData(humidity, pHumChar);
        Serial.print("Sent hum: "); Serial.println(humidity);
        publish_hum = false;
        humidityBuffer = humidity;
      }
    }

    if (millis() - last_time_published_CO2 >= publish_time_CO2) {
      last_time_published_CO2 = millis();
      if(publish_co2) {
        publishData(CO2, pCO2Char);
        Serial.print("Sent co2: "); Serial.println(CO2);
        publish_co2 = false;
        CO2Buffer = CO2;
      }
    }

  }

  // disconnecting
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // give the bluetooth stack the chance to get things ready
    pServer->startAdvertising(); // restart advertising
    Serial.println("start advertising");
    oldDeviceConnected = deviceConnected;
  }

  // connecting
  if (deviceConnected && !oldDeviceConnected) {
    // do stuff here on connecting
    oldDeviceConnected = deviceConnected;
  }

  delay(DEFAULT_WAIT);
}

void publishData(float value, BLECharacteristic *bleChar) {
  uint32_t sendBuffer = uint32_t(value * 100);
  bleChar->setValue((uint8_t*)&sendBuffer, 4);
  bleChar->notify();
}

void interpretData() {
  int r = 0;
  int g = 255;
  if (CO2 >= 800) {
    r = map(CO2, 800, 1400, 0, 255);
    r = constrain(r, 0, 255);
  }
  if (CO2 >= 1400) {
    g = map(CO2, 1400, 2000, 255, 0);
    g = constrain(g, 0, 255);
  }

  analogWrite(LED_R, r);
  analogWrite(LED_G, g);
}

void printEnvData() {
  display.clearDisplay();
  display.setCursor(0, 0);
  display.print("CO2: "); display.print(CO2); display.println("ppm");
  display.print("Temperature: "); display.print(temp); display.println("C");
  display.print("Humidity: "); display.print(humidity); display.print("%");

  display.display();
}

void touch_callback() {
  static unsigned long last_interrupt_time = 0;
  unsigned long interrupt_time = millis();
  if (interrupt_time - last_interrupt_time > 500) {
    turnON = true;
    showDataTimer = millis();
  }
  last_interrupt_time = interrupt_time;
}

void printMHZ19infos() {
  display.clearDisplay();
  display.setCursor(0, 0);
  display.setTextSize(2);
  display.print("ABC: ");
  mhz19.getABC() ? display.println("AN") : display.println("AUS");
  display.print("Bis ");
  display.print(mhz19.getRange());
  display.display();

  delay(3000);
  display.setTextSize(1);
  display.clearDisplay();
}
