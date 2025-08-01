# 🚗 CNG Meter Reading App – POC

A mobile application to capture, process, and submit **CNG fuel dispenser meter readings** using camera-based OCR and AI, with support for **offline mode**, **editable values**, and **GPS tagging**.

---

## 📌 Overview

This Proof of Concept (POC) demonstrates a smart solution for digitizing CNG meter readings using a smartphone. It automates data extraction from fuel meters, reduces manual entry errors, and stores readings with location and time information.

---

## 🚀 Key Features

- 🔍 **OCR & AI-based Reading Extraction**
    - Uses Google ML Kit and Gemini (if online) for reading extraction.
- 📷 **Camera & Gallery Support**
    - Capture meter readings via camera or select from gallery.
- ✏️ **Editable Readings**
    - Allows manual editing of auto-detected values before submission.
- 🌐 **Offline Mode**
    - Submissions are saved locally when offline and synced later.
- 📍 **GPS Location Tagging**
    - Reverse geocoding to attach area name to each reading.
- 🔄 **Bottom Navigation**
    - Easy access to Dashboard, History, and Input screens.
- 🧾 **Fuel Data Formatting**
    - Displays Total Price, Volume, and Price/Litre in a user-friendly format.

---

## 📷 Camera-Based Reading

1. Open the camera or gallery from the dashboard.
2. App automatically detects fuel readings from the image.
3. Values are parsed and displayed for review.

---

## ✏️ Editable Readings

Before final submission, users can:
- Edit Total Price, Litres, or Price/Litre
- Review and confirm the auto-extracted values

---

## 🌐 Offline Mode

- If no internet is detected:
    - App falls back to ML Kit OCR.
    - Saves data locally using Hive.
- Data can be synced when connectivity is restored.

---

## 🔄 Bottom Navigation & UI Enhancements

- Smooth navigation across sections
- Clean UI with persistent internet status banner
- User feedback integrated into dialog confirmations

---

## 🔐 Permissions Required

- **Camera** – for capturing meter images
- **Gallery** – for image selection
- **Location** – for tagging submissions with area name

---

## 📎 Future Enhancements

- Cloud sync & backend integration
- Admin dashboard for monitoring
- Image quality checks and error feedback
- Export readings to Excel/PDF

---

## 🛠 Tech Stack

- **Flutter** (Frontend)
- **Google ML Kit** (Offline OCR)
- **Hive** (Local storage)
- **Geolocator & Geocoding** (GPS tagging)

---


---

## 🧪 Status

✅ POC completed and tested  
🚧 Production readiness and backend integration pending

---

## 🤝 Contributions

This is an internal POC – not open for external contributions at this time.

---

## 📄 License

This project is for demonstration purposes only. Licensing will be defined in production phase.



