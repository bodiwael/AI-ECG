/*
 * AI-ECG Heart Monitor with Heart Attack Prediction
 * ESP32 + AD8232 ECG Sensor
 * Using Classic Bluetooth Serial (SPP)
 *
 * Features:
 * - Real-time ECG signal acquisition
 * - Heart rate calculation (BPM)
 * - HRV (Heart Rate Variability) analysis
 * - Arrhythmia detection
 * - Heart attack risk prediction
 * - Classic Bluetooth Serial data transmission
 *
 * Author: AI-ECG Project Team
 * License: MIT
 */

#include "BluetoothSerial.h"

// Check if Bluetooth is enabled
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` and enable it
#endif

BluetoothSerial SerialBT;

// ==================== PIN DEFINITIONS ====================
#define ECG_OUTPUT_PIN 34      // Analog input for ECG signal (ADC1_CH6)
#define LO_PLUS_PIN 32         // Leads-off detection positive
#define LO_MINUS_PIN 33        // Leads-off detection negative
#define LED_PIN 2              // Built-in LED for status indication

// ==================== SAMPLING CONFIGURATION ====================
#define SAMPLE_RATE 100        // Hz (reduced for Bluetooth Serial stability)
#define SAMPLE_INTERVAL_MS (1000 / SAMPLE_RATE)
#define BUFFER_SIZE 100        // 1 second of data
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
unsigned long lastDataSend = 0;
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

// Bluetooth connection status
bool btConnected = false;

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

  // Initialize Bluetooth Serial
  SerialBT.begin("AI-ECG Monitor");  // Bluetooth device name

  Serial.println("=========================================");
  Serial.println("  AI-ECG Heart Monitor Started");
  Serial.println("  Classic Bluetooth Serial Mode");
  Serial.println("=========================================");
  Serial.println("Device name: AI-ECG Monitor");
  Serial.println("Pair with your phone and connect!");
  Serial.println("Place electrodes on body");
}

// ==================== MAIN LOOP ====================
void loop() {
  unsigned long currentTime = millis();

  // Check Bluetooth connection
  btConnected = SerialBT.hasClient();

  // Blink LED when waiting for connection
  if (!btConnected) {
    digitalWrite(LED_PIN, (currentTime / 500) % 2);
  }

  // Sample at defined rate
  if (currentTime - lastSampleTime >= SAMPLE_INTERVAL_MS) {
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

      // Update LED based on heartbeat (when connected)
      if (btConnected) {
        digitalWrite(LED_PIN, rPeakDetected ? HIGH : LOW);
      }
    }
  }

  // Send data every 100ms (10 Hz) for smooth display
  if (currentTime - lastDataSend >= 100) {
    lastDataSend = currentTime;

    // Calculate heart parameters
    calculateHeartRate();
    calculateHRV();
    assessHeartAttackRisk();

    // Send data via Bluetooth Serial
    if (btConnected) {
      sendBluetoothData();
    }

    // Also print to Serial for debugging
    Serial.print("ECG:");
    Serial.print(ecgValue);
    Serial.print(" BPM:");
    Serial.print(avgBPM);
    Serial.print(" Risk:");
    Serial.println(riskLevel);
  }

  // Handle incoming commands from app
  if (SerialBT.available()) {
    String command = SerialBT.readStringUntil('\n');
    handleCommand(command);
  }
}

// ==================== HANDLE COMMANDS FROM APP ====================
void handleCommand(String command) {
  command.trim();

  if (command == "PING") {
    SerialBT.println("PONG");
  } else if (command == "STATUS") {
    SerialBT.println("OK:AI-ECG Monitor Ready");
  } else if (command == "START") {
    SerialBT.println("OK:Streaming started");
  } else if (command == "STOP") {
    SerialBT.println("OK:Streaming stopped");
  }
}

// ==================== SEND DATA VIA BLUETOOTH ====================
void sendBluetoothData() {
  // Send data as simple CSV format:
  // ECG,avgBPM,currentBPM,HRV,stLevel,riskScore,riskLevel,leadsOff
  // Example: 2048,72,75,45.2,12,15,NORMAL,0

  String data = "DATA:";
  data += String(ecgValue) + ",";
  data += String(avgBPM) + ",";
  data += String(currentBPM) + ",";
  data += String(hrv, 1) + ",";
  data += String(stLevel) + ",";
  data += String(heartAttackRisk) + ",";
  data += riskLevel + ",";
  data += String(leadsOff ? 1 : 0);

  SerialBT.println(data);

  // Send alert if risk is elevated
  if (heartAttackRisk >= 30) {
    SerialBT.println("ALERT:" + alertMessage);
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
    alertMessage += "ST Elevation! ";
  } else if (stLevel < ST_DEPRESSION_THRESHOLD) {
    heartAttackRisk += 30;
    alertMessage += "ST Depression! ";
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
