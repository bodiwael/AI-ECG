/*
 * AI-ECG Heart Monitor with Heart Attack Prediction
 * ESP32 + AD8232 ECG Sensor
 *
 * Features:
 * - Real-time ECG signal acquisition
 * - Heart rate calculation (BPM)
 * - HRV (Heart Rate Variability) analysis
 * - Arrhythmia detection
 * - Heart attack risk prediction
 * - Bluetooth Low Energy (BLE) data transmission
 *
 * Author: AI-ECG Project Team
 * License: MIT
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ==================== PIN DEFINITIONS ====================
#define ECG_OUTPUT_PIN 34      // Analog input for ECG signal (ADC1_CH6)
#define LO_PLUS_PIN 32         // Leads-off detection positive
#define LO_MINUS_PIN 33        // Leads-off detection negative
#define LED_PIN 2              // Built-in LED for status indication

// ==================== BLE CONFIGURATION ====================
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define ECG_CHAR_UUID       "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define PARAMS_CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a9"
#define ALERT_CHAR_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26aa"

// ==================== SAMPLING CONFIGURATION ====================
#define SAMPLE_RATE 500        // Hz
#define SAMPLE_INTERVAL_US (1000000 / SAMPLE_RATE)
#define BUFFER_SIZE 500        // 1 second of data
#define RR_BUFFER_SIZE 20      // For HRV calculation

// ==================== DETECTION THRESHOLDS ====================
#define R_PEAK_THRESHOLD 2800  // Adjust based on your setup
#define MIN_RR_INTERVAL 200    // Minimum RR interval (ms) - 300 BPM max
#define MAX_RR_INTERVAL 2000   // Maximum RR interval (ms) - 30 BPM min
#define ST_ELEVATION_THRESHOLD 200  // ST segment elevation threshold
#define ST_DEPRESSION_THRESHOLD -150 // ST segment depression threshold
#define BRADYCARDIA_THRESHOLD 60    // BPM
#define TACHYCARDIA_THRESHOLD 100   // BPM

// ==================== GLOBAL VARIABLES ====================
// ECG Data
int ecgBuffer[BUFFER_SIZE];
int bufferIndex = 0;
int ecgValue = 0;

// Timing
unsigned long lastSampleTime = 0;
unsigned long lastBLEUpdate = 0;
unsigned long lastRPeakTime = 0;

// Heart Rate Analysis
int rrIntervals[RR_BUFFER_SIZE];
int rrIndex = 0;
int currentBPM = 0;
int avgBPM = 0;
float hrv = 0;  // SDNN (Standard Deviation of NN intervals)

// ST Segment Analysis
int stLevel = 0;
int baselineLevel = 2048;  // Mid-point of 12-bit ADC

// Detection Flags
bool leadsOff = false;
bool rPeakDetected = false;
bool arrhythmiaDetected = false;
bool stAbnormal = false;

// Risk Assessment
int heartAttackRisk = 0;  // 0-100 scale
String riskLevel = "NORMAL";
String alertMessage = "";

// BLE
BLEServer* pServer = NULL;
BLECharacteristic* pEcgCharacteristic = NULL;
BLECharacteristic* pParamsCharacteristic = NULL;
BLECharacteristic* pAlertCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// ==================== BLE CALLBACKS ====================
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("BLE Device Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("BLE Device Disconnected");
    }
};

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);

  // Configure pins
  pinMode(LO_PLUS_PIN, INPUT);
  pinMode(LO_MINUS_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);

  // Configure ADC
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  // Initialize buffers
  memset(ecgBuffer, 0, sizeof(ecgBuffer));
  memset(rrIntervals, 0, sizeof(rrIntervals));

  // Initialize BLE
  initBLE();

  Serial.println("=========================================");
  Serial.println("  AI-ECG Heart Monitor Started");
  Serial.println("  With Heart Attack Prediction");
  Serial.println("=========================================");
  Serial.println("Place electrodes on body");
  Serial.println("Waiting for BLE connection...");
}

// ==================== BLE INITIALIZATION ====================
void initBLE() {
  BLEDevice::init("AI-ECG Monitor");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  // ECG Signal Characteristic
  pEcgCharacteristic = pService->createCharacteristic(
    ECG_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pEcgCharacteristic->addDescriptor(new BLE2902());

  // Parameters Characteristic (BPM, HRV, ST, Risk)
  pParamsCharacteristic = pService->createCharacteristic(
    PARAMS_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pParamsCharacteristic->addDescriptor(new BLE2902());

  // Alert Characteristic
  pAlertCharacteristic = pService->createCharacteristic(
    ALERT_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pAlertCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
}

// ==================== MAIN LOOP ====================
void loop() {
  unsigned long currentTime = micros();

  // Sample at defined rate
  if (currentTime - lastSampleTime >= SAMPLE_INTERVAL_US) {
    lastSampleTime = currentTime;

    // Check leads connection
    leadsOff = (digitalRead(LO_PLUS_PIN) == HIGH || digitalRead(LO_MINUS_PIN) == HIGH);

    if (!leadsOff) {
      // Read ECG signal
      ecgValue = analogRead(ECG_OUTPUT_PIN);

      // Store in buffer
      ecgBuffer[bufferIndex] = ecgValue;
      bufferIndex = (bufferIndex + 1) % BUFFER_SIZE;

      // Process signal
      detectRPeak(ecgValue);
      analyzeSTSegment();

      // Update LED based on heartbeat
      digitalWrite(LED_PIN, rPeakDetected ? HIGH : LOW);

      // Serial output for plotter
      Serial.println(ecgValue);
    } else {
      Serial.println("LEADS_OFF");
    }
  }

  // Update BLE every 50ms
  if (millis() - lastBLEUpdate >= 50) {
    lastBLEUpdate = millis();

    // Calculate heart parameters
    calculateHeartRate();
    calculateHRV();
    assessHeartAttackRisk();

    // Send data via BLE
    if (deviceConnected) {
      sendBLEData();
    }
  }

  // Handle BLE reconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Advertising restarted");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
}

// ==================== R-PEAK DETECTION ====================
void detectRPeak(int sample) {
  static int lastSample = 0;
  static int peakValue = 0;
  static bool ascending = false;

  unsigned long currentTime = millis();

  // Simple peak detection
  if (sample > lastSample) {
    ascending = true;
    peakValue = sample;
  } else if (ascending && sample < lastSample) {
    ascending = false;

    // Check if this is an R-peak
    if (peakValue > R_PEAK_THRESHOLD) {
      unsigned long rrInterval = currentTime - lastRPeakTime;

      // Validate RR interval
      if (rrInterval >= MIN_RR_INTERVAL && rrInterval <= MAX_RR_INTERVAL) {
        // Store RR interval
        rrIntervals[rrIndex] = rrInterval;
        rrIndex = (rrIndex + 1) % RR_BUFFER_SIZE;

        lastRPeakTime = currentTime;
        rPeakDetected = true;
      }
    }
  }

  lastSample = sample;

  // Reset R-peak flag after short delay
  if (rPeakDetected && (currentTime - lastRPeakTime > 100)) {
    rPeakDetected = false;
  }
}

// ==================== HEART RATE CALCULATION ====================
void calculateHeartRate() {
  // Calculate average RR interval
  long totalRR = 0;
  int validIntervals = 0;

  for (int i = 0; i < RR_BUFFER_SIZE; i++) {
    if (rrIntervals[i] > 0) {
      totalRR += rrIntervals[i];
      validIntervals++;
    }
  }

  if (validIntervals > 0) {
    float avgRR = totalRR / (float)validIntervals;
    avgBPM = (int)(60000.0 / avgRR);

    // Current instantaneous BPM
    int lastRR = rrIntervals[(rrIndex - 1 + RR_BUFFER_SIZE) % RR_BUFFER_SIZE];
    if (lastRR > 0) {
      currentBPM = (int)(60000.0 / lastRR);
    }
  }
}

// ==================== HRV CALCULATION (SDNN) ====================
void calculateHRV() {
  // Calculate SDNN (Standard Deviation of NN intervals)
  if (rrIntervals[0] == 0) return;  // Not enough data

  // Calculate mean
  long sum = 0;
  int count = 0;
  for (int i = 0; i < RR_BUFFER_SIZE; i++) {
    if (rrIntervals[i] > 0) {
      sum += rrIntervals[i];
      count++;
    }
  }

  if (count < 5) return;  // Need at least 5 intervals

  float mean = sum / (float)count;

  // Calculate variance
  float variance = 0;
  for (int i = 0; i < RR_BUFFER_SIZE; i++) {
    if (rrIntervals[i] > 0) {
      float diff = rrIntervals[i] - mean;
      variance += diff * diff;
    }
  }
  variance /= count;

  // SDNN is square root of variance
  hrv = sqrt(variance);
}

// ==================== ST SEGMENT ANALYSIS ====================
void analyzeSTSegment() {
  // Simplified ST segment analysis
  // In real implementation, this should be more sophisticated

  // Get baseline (average of buffer)
  long sum = 0;
  for (int i = 0; i < BUFFER_SIZE; i++) {
    sum += ecgBuffer[i];
  }
  baselineLevel = sum / BUFFER_SIZE;

  // ST level relative to baseline
  stLevel = ecgValue - baselineLevel;

  // Check for ST abnormalities
  stAbnormal = (stLevel > ST_ELEVATION_THRESHOLD || stLevel < ST_DEPRESSION_THRESHOLD);
}

// ==================== HEART ATTACK RISK ASSESSMENT ====================
void assessHeartAttackRisk() {
  heartAttackRisk = 0;
  alertMessage = "";

  // Factor 1: ST Segment Abnormalities (40% weight)
  if (stLevel > ST_ELEVATION_THRESHOLD) {
    heartAttackRisk += 40;
    alertMessage += "ST Elevation detected! ";
  } else if (stLevel < ST_DEPRESSION_THRESHOLD) {
    heartAttackRisk += 30;
    alertMessage += "ST Depression detected! ";
  }

  // Factor 2: Abnormal Heart Rate (25% weight)
  if (avgBPM < BRADYCARDIA_THRESHOLD && avgBPM > 0) {
    heartAttackRisk += 15;
    alertMessage += "Bradycardia! ";
  } else if (avgBPM > TACHYCARDIA_THRESHOLD) {
    heartAttackRisk += 20;
    alertMessage += "Tachycardia! ";
  }

  // Factor 3: Low HRV (20% weight)
  // Low HRV is associated with increased cardiac risk
  if (hrv > 0 && hrv < 20) {
    heartAttackRisk += 20;
    alertMessage += "Low HRV! ";
  } else if (hrv >= 20 && hrv < 50) {
    heartAttackRisk += 10;
  }

  // Factor 4: Arrhythmia Detection (15% weight)
  detectArrhythmia();
  if (arrhythmiaDetected) {
    heartAttackRisk += 15;
    alertMessage += "Irregular rhythm! ";
  }

  // Determine risk level
  if (heartAttackRisk >= 70) {
    riskLevel = "CRITICAL";
  } else if (heartAttackRisk >= 50) {
    riskLevel = "HIGH";
  } else if (heartAttackRisk >= 30) {
    riskLevel = "MODERATE";
  } else if (heartAttackRisk >= 15) {
    riskLevel = "LOW";
  } else {
    riskLevel = "NORMAL";
  }

  if (alertMessage.length() == 0) {
    alertMessage = "Normal sinus rhythm";
  }
}

// ==================== ARRHYTHMIA DETECTION ====================
void detectArrhythmia() {
  // Check for irregular RR intervals (simple arrhythmia detection)
  if (rrIntervals[0] == 0) {
    arrhythmiaDetected = false;
    return;
  }

  int irregularCount = 0;
  int prevRR = rrIntervals[0];

  for (int i = 1; i < RR_BUFFER_SIZE; i++) {
    if (rrIntervals[i] > 0) {
      int diff = abs(rrIntervals[i] - prevRR);
      // If RR interval changes by more than 20%, count as irregular
      if (diff > (prevRR * 0.2)) {
        irregularCount++;
      }
      prevRR = rrIntervals[i];
    }
  }

  // If more than 30% of intervals are irregular
  arrhythmiaDetected = (irregularCount > RR_BUFFER_SIZE * 0.3);
}

// ==================== BLE DATA TRANSMISSION ====================
void sendBLEData() {
  // Send ECG value (2 bytes)
  uint8_t ecgData[2];
  ecgData[0] = (ecgValue >> 8) & 0xFF;
  ecgData[1] = ecgValue & 0xFF;
  pEcgCharacteristic->setValue(ecgData, 2);
  pEcgCharacteristic->notify();

  // Send parameters as JSON-like string
  String params = String(avgBPM) + "," +
                  String(currentBPM) + "," +
                  String(hrv, 1) + "," +
                  String(stLevel) + "," +
                  String(heartAttackRisk) + "," +
                  riskLevel + "," +
                  String(leadsOff ? 1 : 0);
  pParamsCharacteristic->setValue(params.c_str());
  pParamsCharacteristic->notify();

  // Send alert if risk is elevated
  if (heartAttackRisk >= 30) {
    pAlertCharacteristic->setValue(alertMessage.c_str());
    pAlertCharacteristic->notify();
  }
}
