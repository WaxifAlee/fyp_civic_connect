# CivicConnect: Crowdsourced Local Issue Reporting System

CivicConnect is a mobile and web-based application designed to bridge the gap between community members and local authorities by facilitating real-time reporting and resolution of local issues. The app leverages crowdsourcing to create a smarter, more connected community while improving the efficiency of local governance.

---

## 📋 Table of Contents

- [Objective](#objective)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [System Architecture](#system-architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Future Enhancements](#future-enhancements)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Objective

The goal of CivicConnect is to:

- Provide a user-friendly platform for residents to report local issues (e.g., broken infrastructure, sanitation problems).
- Enable authorities to manage, prioritize, and resolve complaints effectively.
- Promote transparency, accountability, and engagement between citizens and local authorities.

---

## ✨ Features

### For Community Users:

- **Issue Reporting**:
  - Submit issues with descriptions, photos, and geolocation.
  - Categorize issues into predefined types (e.g., roads, water, electricity).
- **Real-time Updates**:
  - Track the status of reported issues (Pending, In Progress, Resolved).
- **Community Engagement**:
  - Upvote issues reported by other users to highlight priorities.
- **Notifications**:
  - Get notified about updates on your submitted issues.

### For Authorities:

- **Admin Dashboard**:
  - View and manage reported issues via a centralized console.
- **Status Management**:
  - Update the status of issues to keep citizens informed.
- **Analytics**:
  - Gain insights into common issues and resolution timelines.

---

## 🛠 Tech Stack

### **Mobile Application**:

- **Framework**: Flutter
- **Backend**: Firebase (Firestore, Authentication, Cloud Storage)
- **APIs**: Google Maps API for geolocation and mapping

### **Web Application**:

- **Framework**: Flutter for Web
- **Backend**: Firebase
- **UI**: Material Design

### **Database**:

- Cloud Firestore (NoSQL database for real-time data synchronization)

### **Cloud Services**:

- Firebase Authentication (User login and management)
- Firebase Cloud Storage (Photo uploads)
- Firebase Notifications (Push notifications for updates)

---

## 🖼 System Architecture

+---------------------+ +-------------------+ +------------------+ | Community Users | <-----> | Firebase Backend | <-----> | Local Authorities | +---------------------+ +-------------------+ +------------------+ | Mobile App (Flutter)| | Firestore DB | | Web App (Flutter) | | Google Maps API | | Authentication | | Admin Dashboard | +---------------------+ +-------------------+ +------------------+

---

## 🚀 Installation

### Prerequisites:

- Flutter installed on your system.
- Firebase project setup for the app.
- Android Studio or VS Code for development.

### Steps:

1. Clone this repository:

   ```bash
   git clone https://github.com/WaxifAlee/fyp_civic_connect.git

   ```

2. Navigate to the project directory
   cd fyp_civic_connect

3. Install dependencies
   flutter pub get

4. Configure Firebase

   - Download the google-services.json (For Android) and GoogleService-Info.plist (For iOS) from your Firebase project.
   - Place them in the respective directories (android/app/ and ios/Runner/)

5. Run the application
   - flutter run

# 📖 Usage

### For Community Users:

1. Sign up or log in using email or Google.
2. Report an issue by completing the required details and attaching a photo.
3. Track the progress of your reported issues under the "My Issues" section.

### For Authorities:

1. Log in to the admin console.
2. View all reported issues categorized by priority.
3. Update the status of issues and provide resolution details.

---

## 🛠 Future Enhancements

- **AI Module**: Integrate AI to analyze and prioritize issues based on severity.
- **Blockchain**: Add a blockchain module for immutable records of complaints.
- **AR/VR**: Enable AR visualization of nearby issues.
- **Gamification**: Reward users for actively reporting and resolving issues.
- **Offline Mode**: Allow users to submit reports without internet, syncing them later.

---

## 🤝 Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create a feature branch:
   ```bash
   git checkout -b feature/YourFeature
   ```
3. Commit your changes:
   ```bash
   git commit -m "Add YourFeature"
   ```
4. Push to the branch:
   ```bash
   git push origin feature/YourFeature
   ```
5. Create a Pull Request.

---

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

### 💡 Acknowledgments

- Google for Firebase and Maps API
- Flutter community for their amazing framework
- OpenAI for support and resources

**Developed with ❤️ by Wasif Ali & Laiba Rustom**
