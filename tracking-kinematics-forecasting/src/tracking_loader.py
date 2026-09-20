import numpy as np
import pandas as pd
from scipy.signal import savgol_filter


def load_metrica_sample(match_id: int = 2) -> pd.DataFrame:
    """Fetches Metrica tracking data sample directly via raw remote CSV."""
    url = (
        f"https://raw.githubusercontent.com/metrica-sports/sample-data/master/"
        f"data/Sample_Game_{match_id}/Sample_Game_{match_id}_RawTrackingData_Home_Team.csv"
    )
    print(f"Ingesting 25Hz telemetry from {url}...")
    df = pd.read_csv(url, skiprows=2)
    return df


def smooth_and_derive_kinematics(
    df: pd.DataFrame, 
    x_col: str, 
    y_col: str, 
    sampling_rate: int = 25
) -> pd.DataFrame:
    """
    Applies Savitzky-Golay smoothing to (x, y) coordinates and computes
    continuous velocity (m/s) and acceleration (m/s^2). Standard pitch: 105m x 68m.
    """
    # Scale normalized coordinates (0-1) to pitch dimensions in meters
    x_m = df[x_col].ffill() * 105.0
    y_m = df[y_col].ffill() * 68.0

    # Savitzky-Golay filter: window length 11 frames (~0.44s), polynomial order 2
    x_smooth = savgol_filter(x_m, window_length=11, polyorder=2)
    y_smooth = savgol_filter(y_m, window_length=11, polyorder=2)

    # Velocity (m/s)
    vx = np.gradient(x_smooth, 1.0 / sampling_rate)
    vy = np.gradient(y_smooth, 1.0 / sampling_rate)
    speed = np.sqrt(vx**2 + vy**2)

    # Acceleration (m/s^2)
    ax = np.gradient(vx, 1.0 / sampling_rate)
    ay = np.gradient(vy, 1.0 / sampling_rate)
    accel = np.sqrt(ax**2 + ay**2)

    out = pd.DataFrame({
        "frame": df.iloc[:, 0],
        "x": x_smooth,
        "y": y_smooth,
        "velocity_mps": speed,
        "accel_mps2": accel,
        "high_intensity_running": (speed >= 5.5).astype(int)  # FA threshold (>19.8 km/h)
    })
    return out


if __name__ == "__main__":
    raw = load_metrica_sample(match_id=2)
    p11_data = smooth_and_derive_kinematics(raw, raw.columns[3], raw.columns[4])
    print("\nTelemetry Extraction & Kinematics Preview:")
    print(p11_data.head(10))