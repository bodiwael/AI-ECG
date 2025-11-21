# AI-ECG: Heart Attack Prediction System

> AI-Driven ECG Image to Signal Conversion for Clinical Data Recovery with Real-time Heart Attack Prediction

تحويل صورة تخطيط القلب الكهربائي إلى إشارة باستخدام الذكاء الاصطناعي لاستعادة البيانات السريرية

---

## Overview

AI-ECG is an integrated system combining artificial intelligence, biosensors, and mobile technology for:

1. **ECG Image Conversion**: Transform scanned/photographed paper ECG recordings into digital signals
2. **Real-time Monitoring**: Capture live ECG signals using AD8232 sensor + ESP32
3. **Heart Attack Prediction**: AI-powered risk assessment with multiple cardiac parameters
4. **Mobile Visualization**: Flutter app with Bluetooth connectivity for real-time monitoring

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AI-ECG System                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Hardware   │    │   Software   │    │  Mobile App  │      │
│  │   (ESP32 +   │───▶│   (Python    │    │   (Flutter)  │      │
│  │   AD8232)    │    │   AI/ML)     │    │              │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                   │                   ▲               │
│         │                   │                   │               │
│         └───────────────────┼───────────────────┘               │
│                             │                                   │
│                    Bluetooth Low Energy (BLE)                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Features

### Hardware Module (ESP32 + AD8232)
- Real-time ECG signal acquisition at 500 Hz
- Heart rate (BPM) calculation
- HRV (Heart Rate Variability) analysis - SDNN
- ST segment elevation/depression detection
- Arrhythmia detection
- Heart attack risk scoring (0-100)
- BLE data transmission to mobile app
- Leads-off detection

### Python AI Module
- ECG image preprocessing (rotation correction, grid removal)
- Waveform extraction using OpenCV
- Signal reconstruction with calibration
- Heart attack risk prediction from extracted signals
- Export to CSV format
- Comprehensive visualization

### Flutter Mobile App
- Bluetooth Low Energy connectivity
- Real-time ECG waveform visualization
- Animated heart rate display
- Heart parameters dashboard (BPM, HRV, ST level)
- Risk assessment indicator
- Alert system for abnormal readings
- Dark theme UI with smooth animations

---

## Project Structure

```
AI-ECG/
├── esp32_firmware/
│   └── ecg_heart_monitor.ino    # ESP32 Arduino firmware
├── python_ai/
│   ├── ecg_image_converter.py   # Image to signal converter
│   └── requirements.txt         # Python dependencies
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── providers/
│   │   │   ├── bluetooth_provider.dart
│   │   │   └── ecg_provider.dart
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   └── widgets/
│   │       ├── ecg_chart.dart
│   │       ├── heart_params_card.dart
│   │       ├── risk_indicator.dart
│   │       ├── connection_button.dart
│   │       ├── device_list_dialog.dart
│   │       └── animated_heart.dart
│   └── pubspec.yaml
└── README.md
```

---

## Hardware Setup

### Components Required
| Component | Description |
|-----------|-------------|
| ESP32 DevKit | Microcontroller with BLE |
| AD8232 ECG Sensor | Heart rate monitor module |
| ECG Electrodes | 3-lead electrode patches |
| Jumper Wires | For connections |

### Wiring Diagram

```
AD8232          ESP32
────────────────────────
3.3V     ──▶   3.3V
GND      ──▶   GND
OUTPUT   ──▶   GPIO 34 (ADC)
LO+      ──▶   GPIO 32
LO-      ──▶   GPIO 33
```

### Electrode Placement
```
        RA (Right Arm)
            ●
           /|\
          / | \
         /  |  \
        /   |   \
       ●────┼────●
      LA    |    RL
  (Left   (Ground)
   Arm)
```

---

## Installation

### 1. ESP32 Firmware

```bash
# Install Arduino IDE or PlatformIO
# Install ESP32 board package
# Open esp32_firmware/ecg_heart_monitor.ino
# Select ESP32 Dev Module
# Upload to ESP32
```

### 2. Python AI Module

```bash
cd python_ai
pip install -r requirements.txt
```

**Usage:**
```python
from ecg_image_converter import ECGImageConverter, HeartAttackPredictor

# Convert ECG image to signal
converter = ECGImageConverter()
time, voltage = converter.process_image('ecg_scan.png')
converter.export_to_csv('output.csv')

# Predict heart attack risk
predictor = HeartAttackPredictor()
features = predictor.extract_features(time, voltage)
risk_score, risk_level, explanation = predictor.predict_risk()
print(f"Risk: {risk_level} ({risk_score}/100)")
```

### 3. Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

**Requirements:**
- Flutter SDK >= 3.0.0
- Android SDK / Xcode for iOS
- Physical device with Bluetooth

---

## Heart Attack Risk Assessment

The system analyzes multiple factors to calculate heart attack risk:

| Factor | Weight | Threshold |
|--------|--------|-----------|
| ST Elevation | 40% | > 100 uV |
| ST Depression | 30% | < -50 uV |
| Tachycardia | 20% | > 100 BPM |
| Bradycardia | 15% | < 60 BPM |
| Low HRV | 20% | SDNN < 20 ms |
| Arrhythmia | 15% | Irregular RR |

### Risk Levels
- **NORMAL** (0-14): No significant risk factors
- **LOW** (15-29): Minor abnormalities detected
- **MODERATE** (30-49): Multiple risk factors present
- **HIGH** (50-69): Significant cardiac concern
- **CRITICAL** (70-100): Immediate medical attention needed

---

## API Reference

### BLE Service UUIDs
```
Service:     4fafc201-1fb5-459e-8fcc-c5c9c331914b
ECG Data:    beb5483e-36e1-4688-b7f5-ea07361b26a8
Parameters:  beb5483e-36e1-4688-b7f5-ea07361b26a9
Alerts:      beb5483e-36e1-4688-b7f5-ea07361b26aa
```

### Data Format
**ECG Characteristic**: 2 bytes (uint16, big-endian)
```
[MSB][LSB] = ECG value (0-4095)
```

**Parameters Characteristic**: CSV string
```
avgBPM,currentBPM,hrv,stLevel,riskScore,riskLevel,leadsOff
Example: "72,75,45.2,12,15,LOW,0"
```

---

## Medical Disclaimer

This system is designed for **educational and research purposes only**. It is NOT a certified medical device and should NOT be used for clinical diagnosis or treatment decisions.

Always consult qualified healthcare professionals for medical advice.

---

## Future Enhancements

- [ ] U-Net deep learning model for improved waveform extraction
- [ ] 12-lead ECG support
- [ ] Cloud synchronization
- [ ] Historical data analysis
- [ ] PDF report generation
- [ ] Integration with health platforms (Apple Health, Google Fit)

---

## License

MIT License

---

## Authors

AI-ECG Project Team
