"""
AI-ECG Image to Signal Converter
================================

This module converts scanned/photographed ECG paper recordings
to digital signals using computer vision and machine learning.

Features:
- Image preprocessing (rotation correction, grid removal)
- ECG waveform extraction using OpenCV and U-Net
- Signal reconstruction with time and voltage calibration
- Heart attack prediction using extracted features

Author: AI-ECG Project Team
License: MIT
"""

import cv2
import numpy as np
import pandas as pd
from scipy import signal, ndimage
from scipy.interpolate import interp1d
import matplotlib.pyplot as plt
from typing import Tuple, List, Optional, Dict
import warnings
warnings.filterwarnings('ignore')


class ECGImageConverter:
    """
    Converts ECG paper images to digital signals.
    """

    def __init__(self,
                 paper_speed: float = 25.0,  # mm/s
                 voltage_scale: float = 10.0,  # mm/mV
                 target_sample_rate: int = 500):  # Hz
        """
        Initialize the ECG Image Converter.

        Args:
            paper_speed: ECG paper speed in mm/s (standard: 25 mm/s)
            voltage_scale: Voltage scale in mm/mV (standard: 10 mm/mV)
            target_sample_rate: Output signal sample rate in Hz
        """
        self.paper_speed = paper_speed
        self.voltage_scale = voltage_scale
        self.target_sample_rate = target_sample_rate
        self.pixels_per_mm = None
        self.image = None
        self.processed_image = None
        self.extracted_signal = None

    def load_image(self, image_path: str) -> np.ndarray:
        """Load and validate ECG image."""
        self.image = cv2.imread(image_path)
        if self.image is None:
            raise ValueError(f"Could not load image: {image_path}")
        return self.image

    def preprocess(self, image: Optional[np.ndarray] = None) -> np.ndarray:
        """
        Preprocess ECG image for waveform extraction.

        Steps:
        1. Convert to grayscale
        2. Correct rotation/skew
        3. Remove grid lines
        4. Enhance contrast
        5. Binarize

        Args:
            image: Input image (uses self.image if None)

        Returns:
            Preprocessed binary image
        """
        if image is None:
            image = self.image

        # Convert to grayscale
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image.copy()

        # Detect and correct rotation
        gray = self._correct_rotation(gray)

        # Estimate grid spacing for calibration
        self.pixels_per_mm = self._estimate_grid_spacing(gray)

        # Remove grid lines
        grid_removed = self._remove_grid(gray)

        # Enhance contrast using CLAHE
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        enhanced = clahe.apply(grid_removed)

        # Gaussian blur to reduce noise
        blurred = cv2.GaussianBlur(enhanced, (3, 3), 0)

        # Adaptive thresholding for binarization
        binary = cv2.adaptiveThreshold(
            blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY_INV, 11, 2
        )

        # Morphological operations to clean up
        kernel = np.ones((2, 2), np.uint8)
        binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
        binary = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel)

        self.processed_image = binary
        return binary

    def _correct_rotation(self, image: np.ndarray) -> np.ndarray:
        """Detect and correct image rotation using Hough transform."""
        edges = cv2.Canny(image, 50, 150, apertureSize=3)

        lines = cv2.HoughLines(edges, 1, np.pi/180, threshold=100)

        if lines is not None:
            angles = []
            for line in lines[:min(20, len(lines))]:
                rho, theta = line[0]
                angle = np.degrees(theta) - 90
                if abs(angle) < 45:
                    angles.append(angle)

            if angles:
                median_angle = np.median(angles)
                if abs(median_angle) > 0.5:
                    h, w = image.shape[:2]
                    center = (w // 2, h // 2)
                    rotation_matrix = cv2.getRotationMatrix2D(center, median_angle, 1.0)
                    image = cv2.warpAffine(image, rotation_matrix, (w, h),
                                          flags=cv2.INTER_LINEAR,
                                          borderMode=cv2.BORDER_REPLICATE)

        return image

    def _estimate_grid_spacing(self, image: np.ndarray) -> float:
        """Estimate pixels per mm from grid pattern."""
        edges = cv2.Canny(image, 30, 100)
        horizontal_projection = np.sum(edges, axis=1)
        peaks, _ = signal.find_peaks(horizontal_projection,
                                     distance=10, prominence=100)

        if len(peaks) > 2:
            spacing = np.median(np.diff(peaks))
            return spacing / 5.0

        return 4.0

    def _remove_grid(self, image: np.ndarray) -> np.ndarray:
        """Remove grid lines while preserving ECG waveform."""
        horizontal_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (40, 1))
        detected_horizontal = cv2.morphologyEx(image, cv2.MORPH_OPEN,
                                               horizontal_kernel, iterations=2)

        vertical_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 40))
        detected_vertical = cv2.morphologyEx(image, cv2.MORPH_OPEN,
                                             vertical_kernel, iterations=2)

        grid_mask = cv2.add(detected_horizontal, detected_vertical)
        grid_mask = cv2.dilate(grid_mask, np.ones((3, 3), np.uint8), iterations=1)

        result = cv2.subtract(image, grid_mask)

        return result

    def extract_waveform(self, image: Optional[np.ndarray] = None) -> np.ndarray:
        """
        Extract ECG waveform coordinates from processed image.

        Args:
            image: Processed binary image (uses self.processed_image if None)

        Returns:
            Array of (x, y) coordinates representing the waveform
        """
        if image is None:
            image = self.processed_image

        h, w = image.shape
        waveform_y = []

        for x in range(w):
            column = image[:, x]
            white_pixels = np.where(column > 0)[0]

            if len(white_pixels) > 0:
                if len(white_pixels) > 1:
                    y = np.mean(white_pixels)
                else:
                    y = white_pixels[0]
                waveform_y.append(y)
            elif waveform_y:
                waveform_y.append(waveform_y[-1])
            else:
                waveform_y.append(h // 2)

        waveform_y = np.array(waveform_y)

        window_size = 5
        waveform_y = ndimage.uniform_filter1d(waveform_y, size=window_size)

        waveform_y = h - waveform_y

        return np.column_stack([np.arange(len(waveform_y)), waveform_y])

    def convert_to_signal(self, waveform: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Convert pixel coordinates to time (seconds) and voltage (mV).

        Args:
            waveform: Array of (x, y) pixel coordinates

        Returns:
            Tuple of (time_array, voltage_array)
        """
        x_pixels = waveform[:, 0]
        y_pixels = waveform[:, 1]

        baseline = np.median(y_pixels)
        y_centered = y_pixels - baseline

        time_mm = x_pixels / self.pixels_per_mm
        time_seconds = time_mm / self.paper_speed

        voltage_mm = y_centered / self.pixels_per_mm
        voltage_mv = voltage_mm / self.voltage_scale

        num_samples = int(time_seconds[-1] * self.target_sample_rate)
        time_resampled = np.linspace(0, time_seconds[-1], num_samples)

        interpolator = interp1d(time_seconds, voltage_mv, kind='cubic',
                               fill_value='extrapolate')
        voltage_resampled = interpolator(time_resampled)

        self.extracted_signal = (time_resampled, voltage_resampled)
        return time_resampled, voltage_resampled

    def process_image(self, image_path: str) -> Tuple[np.ndarray, np.ndarray]:
        """
        Complete pipeline: load image and extract digital signal.

        Args:
            image_path: Path to ECG image file

        Returns:
            Tuple of (time_array, voltage_array) in seconds and mV
        """
        self.load_image(image_path)
        self.preprocess()
        waveform = self.extract_waveform()
        return self.convert_to_signal(waveform)

    def export_to_csv(self, output_path: str,
                     time: Optional[np.ndarray] = None,
                     voltage: Optional[np.ndarray] = None) -> str:
        """Export extracted signal to CSV file."""
        if time is None or voltage is None:
            if self.extracted_signal is None:
                raise ValueError("No signal extracted. Run process_image first.")
            time, voltage = self.extracted_signal

        df = pd.DataFrame({
            'time_s': time,
            'voltage_mV': voltage,
            'sample_index': np.arange(len(time))
        })

        df.to_csv(output_path, index=False)
        return output_path


class HeartAttackPredictor:
    """
    Predicts heart attack risk from ECG signal features.
    """

    def __init__(self):
        self.features = {}
        self.risk_score = 0
        self.risk_level = "UNKNOWN"

    def extract_features(self, time: np.ndarray, voltage: np.ndarray) -> Dict:
        """Extract clinical features from ECG signal."""
        features = {}

        r_peaks = self._detect_r_peaks(voltage)
        features['r_peak_count'] = len(r_peaks)

        if len(r_peaks) > 1:
            rr_intervals = np.diff(time[r_peaks])
            features['heart_rate'] = 60 / np.mean(rr_intervals) if np.mean(rr_intervals) > 0 else 0
            features['hrv_sdnn'] = np.std(rr_intervals) * 1000
            features['hrv_rmssd'] = np.sqrt(np.mean(np.diff(rr_intervals)**2)) * 1000
        else:
            features['heart_rate'] = 0
            features['hrv_sdnn'] = 0
            features['hrv_rmssd'] = 0

        st_segments = self._analyze_st_segments(voltage, r_peaks)
        features['st_elevation'] = st_segments.get('elevation', 0)
        features['st_depression'] = st_segments.get('depression', 0)
        features['st_abnormal'] = st_segments.get('abnormal', False)

        qrs_features = self._analyze_qrs(voltage, r_peaks)
        features['qrs_duration'] = qrs_features.get('duration', 0)
        features['qrs_amplitude'] = qrs_features.get('amplitude', 0)

        features['signal_quality'] = self._assess_signal_quality(voltage)

        self.features = features
        return features

    def _detect_r_peaks(self, voltage: np.ndarray,
                       sample_rate: int = 500) -> np.ndarray:
        """Detect R-peaks using Pan-Tompkins-like algorithm."""
        sos = signal.butter(2, [5, 15], 'bandpass',
                           fs=sample_rate, output='sos')
        filtered = signal.sosfilt(sos, voltage)

        diff = np.diff(filtered)
        squared = diff ** 2

        window_size = int(0.15 * sample_rate)
        integrated = np.convolve(squared, np.ones(window_size)/window_size,
                                mode='same')

        threshold = np.mean(integrated) + 0.5 * np.std(integrated)
        peaks, _ = signal.find_peaks(integrated, height=threshold,
                                     distance=int(0.3 * sample_rate))

        return peaks

    def _analyze_st_segments(self, voltage: np.ndarray,
                            r_peaks: np.ndarray) -> Dict:
        """Analyze ST segments for elevation/depression."""
        result = {'elevation': 0, 'depression': 0, 'abnormal': False}

        if len(r_peaks) < 2:
            return result

        st_levels = []
        for peak in r_peaks[:-1]:
            j_point = peak + int(0.08 * 500)
            st_point = peak + int(0.12 * 500)

            if st_point < len(voltage):
                st_level = np.mean(voltage[j_point:st_point])
                st_levels.append(st_level)

        if st_levels:
            avg_st = np.mean(st_levels)
            baseline = np.median(voltage)

            st_deviation = (avg_st - baseline) * 1000

            if st_deviation > 100:
                result['elevation'] = st_deviation
                result['abnormal'] = True
            elif st_deviation < -50:
                result['depression'] = abs(st_deviation)
                result['abnormal'] = True

        return result

    def _analyze_qrs(self, voltage: np.ndarray,
                    r_peaks: np.ndarray) -> Dict:
        """Analyze QRS complex characteristics."""
        result = {'duration': 0, 'amplitude': 0}

        if len(r_peaks) < 1:
            return result

        amplitudes = []
        durations = []

        for peak in r_peaks:
            q_search_start = max(0, peak - int(0.1 * 500))
            s_search_end = min(len(voltage), peak + int(0.1 * 500))

            segment = voltage[q_search_start:s_search_end]
            if len(segment) > 0:
                amplitudes.append(voltage[peak] - np.min(segment))

                threshold = (voltage[peak] - np.min(segment)) * 0.1
                above_threshold = np.where(segment > (np.min(segment) + threshold))[0]
                if len(above_threshold) > 0:
                    durations.append((above_threshold[-1] - above_threshold[0]) / 500 * 1000)

        if amplitudes:
            result['amplitude'] = np.mean(amplitudes)
        if durations:
            result['duration'] = np.mean(durations)

        return result

    def _assess_signal_quality(self, voltage: np.ndarray) -> float:
        """Assess signal quality (0-100 scale)."""
        snr = np.mean(np.abs(voltage)) / (np.std(voltage) + 1e-10)
        quality = min(100, snr * 20)
        return quality

    def predict_risk(self, features: Optional[Dict] = None) -> Tuple[int, str, str]:
        """
        Predict heart attack risk based on extracted features.

        Returns:
            Tuple of (risk_score, risk_level, explanation)
        """
        if features is None:
            features = self.features

        risk_score = 0
        explanations = []

        if features.get('st_elevation', 0) > 100:
            risk_score += 40
            explanations.append(f"ST elevation: {features['st_elevation']:.0f} uV")
        elif features.get('st_depression', 0) > 50:
            risk_score += 30
            explanations.append(f"ST depression: {features['st_depression']:.0f} uV")

        hr = features.get('heart_rate', 70)
        if hr < 50:
            risk_score += 15
            explanations.append(f"Bradycardia: {hr:.0f} BPM")
        elif hr > 100:
            risk_score += 20
            explanations.append(f"Tachycardia: {hr:.0f} BPM")

        hrv = features.get('hrv_sdnn', 50)
        if hrv < 20:
            risk_score += 20
            explanations.append(f"Low HRV: {hrv:.1f} ms")
        elif hrv < 50:
            risk_score += 10

        qrs = features.get('qrs_duration', 100)
        if qrs > 120:
            risk_score += 15
            explanations.append(f"Wide QRS: {qrs:.0f} ms")

        quality = features.get('signal_quality', 50)
        if quality < 30:
            explanations.append("Warning: Low signal quality")

        if risk_score >= 70:
            risk_level = "CRITICAL"
        elif risk_score >= 50:
            risk_level = "HIGH"
        elif risk_score >= 30:
            risk_level = "MODERATE"
        elif risk_score >= 15:
            risk_level = "LOW"
        else:
            risk_level = "NORMAL"

        explanation = "; ".join(explanations) if explanations else "Normal sinus rhythm"

        self.risk_score = risk_score
        self.risk_level = risk_level

        return risk_score, risk_level, explanation


def visualize_results(original_image: np.ndarray,
                     processed_image: np.ndarray,
                     time: np.ndarray,
                     voltage: np.ndarray,
                     features: Dict,
                     risk_info: Tuple) -> plt.Figure:
    """Create comprehensive visualization of ECG analysis results."""
    fig = plt.figure(figsize=(16, 10))

    ax1 = fig.add_subplot(2, 3, 1)
    ax1.imshow(cv2.cvtColor(original_image, cv2.COLOR_BGR2RGB))
    ax1.set_title('Original ECG Image')
    ax1.axis('off')

    ax2 = fig.add_subplot(2, 3, 2)
    ax2.imshow(processed_image, cmap='gray')
    ax2.set_title('Processed Image')
    ax2.axis('off')

    ax3 = fig.add_subplot(2, 1, 2)
    ax3.plot(time, voltage, 'b-', linewidth=0.8)
    ax3.set_xlabel('Time (seconds)')
    ax3.set_ylabel('Voltage (mV)')
    ax3.set_title('Extracted ECG Signal')
    ax3.grid(True, alpha=0.3)
    ax3.set_xlim([0, min(10, time[-1])])

    risk_score, risk_level, explanation = risk_info

    colors = {
        'NORMAL': 'green',
        'LOW': 'yellowgreen',
        'MODERATE': 'orange',
        'HIGH': 'orangered',
        'CRITICAL': 'red'
    }

    ax4 = fig.add_subplot(2, 3, 3)
    ax4.axis('off')

    info_text = f"""
    Heart Rate: {features.get('heart_rate', 0):.0f} BPM
    HRV (SDNN): {features.get('hrv_sdnn', 0):.1f} ms
    QRS Duration: {features.get('qrs_duration', 0):.0f} ms
    Signal Quality: {features.get('signal_quality', 0):.0f}%

    Risk Score: {risk_score}/100
    Risk Level: {risk_level}

    {explanation}
    """

    ax4.text(0.1, 0.9, info_text, transform=ax4.transAxes,
            fontsize=11, verticalalignment='top',
            fontfamily='monospace',
            bbox=dict(boxstyle='round', facecolor=colors.get(risk_level, 'white'),
                     alpha=0.3))
    ax4.set_title('Analysis Results')

    plt.tight_layout()
    return fig


if __name__ == "__main__":
    print("AI-ECG Image to Signal Converter")
    print("=" * 40)
    print("\nUsage:")
    print("  from ecg_image_converter import ECGImageConverter, HeartAttackPredictor")
    print("  ")
    print("  # Convert ECG image to signal")
    print("  converter = ECGImageConverter()")
    print("  time, voltage = converter.process_image('ecg_image.png')")
    print("  converter.export_to_csv('output.csv')")
    print("  ")
    print("  # Predict heart attack risk")
    print("  predictor = HeartAttackPredictor()")
    print("  features = predictor.extract_features(time, voltage)")
    print("  risk_score, risk_level, explanation = predictor.predict_risk()")
