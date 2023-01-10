// DHT22
#define DHTPIN 27
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

#define LED_R 25
#define LED_G 33
#define LED_B 32
#define TOUCH 12
#define TOUCH_THRESHOLD 40

// MH-Z19
#define PREHEAT_SECONDS 60
#define SERIAL_BAUDRATE 115200
#define RX_PIN 16   // Rx pin which the MHZ19 Tx pin is attached to
#define TX_PIN 17   // Tx pin which the MHZ19 Rx pin is attached to
#define MHZ19_BAUDRATE 9600
#define MHZ19_PROTOCOL SERIAL_8N1
#define MHZ19_RANGE 5000
MHZ19 mhz19;

#define WAIT_SEC 5
unsigned long getDataTimer = 0;
int CO2 = 0;
float temp = 0;
float humidity = 0;

int CO2Buffer = 0;
float tempBuffer = 0;
float humidityBuffer = 0;

bool publish_co2 = false;
bool publish_temp = false;
bool publish_hum = false;
bool forcePublish_co2 = false;
bool forcePublish_temp = false;
bool forcePublish_hum = false;

#define THRESHOLD 0.05

void getEnvData() {

  if (millis() - getDataTimer >= 1000 * WAIT_SEC) {
    getDataTimer = millis();

    CO2 = mhz19.getCO2();
    temp = dht.readTemperature();
    humidity = dht.readHumidity();

    publish_co2 = (CO2 == CO2Buffer) ? false : true;
    publish_temp = (temp == tempBuffer) ? false : true;
    publish_hum = (humidity == humidityBuffer) ? false : true;

    forcePublish_co2 = (CO2 >= CO2Buffer * (1+THRESHOLD) || CO2 <= CO2Buffer * (1-THRESHOLD)) ? true : false;
    forcePublish_temp = (temp >= tempBuffer * (1+THRESHOLD) || temp <= tempBuffer * (1-THRESHOLD)) ? true : false;
    forcePublish_hum = (humidity >= humidityBuffer * (1+THRESHOLD) || humidity <= humidityBuffer * (1-THRESHOLD)) ? true : false;
  }

}
