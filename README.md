# 🐟 AquaGlass - IoT Fish Feeder App

Welcome to **AquaGlass**! This project is a complete ecosystem for an IoT-based automatic fish feeder system. 

If you are new to the project, don't worry! This guide is designed to help you understand how everything fits together. The project is split into two main components:
1. **Frontend**: A Flutter-based application that can run on Mobile (Android/iOS) and Web.
2. **Backend**: A Node.js & Express REST API that handles data, authentication, and device management.

---

## 📂 Project Structure Explained (For Newbies)

Here is a simple breakdown of the important files and folders in this repository so you know exactly where to look when making changes.

### 📱 Frontend (Flutter App)
The frontend code is located in the root of the project.
* `lib/` — **This is where all the Flutter Dart code lives!**
  * `main.dart` — The entry point of the app. This is where the app starts running.
  * `screens/` — Contains all the visual pages (like the Login screen, Dashboard, etc.).
  * `widgets/` — Reusable UI components (like buttons, cards, input fields).
  * `models/` — Defines the structure of the data used in the app (e.g., what a "User" or "Device" looks like).
  * `services/` — Handles external communication (like making API calls to the backend).
  * `config/` — Configuration files and constants.
* `pubspec.yaml` — This is the package manager file for Flutter. It lists all the external libraries the app depends on (like `google_fonts`, `http`), as well as images/fonts.
* `android/`, `ios/`, `web/` — Platform-specific folders that Flutter uses to build the app for these respective platforms. You rarely need to touch these unless you are doing platform-specific setup.

### ⚙️ Backend (Node.js API)
The backend code is entirely contained within the `backend/` folder.
* `server.js` — The main entry point of the backend server. It sets up the server, connects to the database, and defines all the API routes.
* `config/` — Contains configuration files (like the MongoDB database connection logic).
* `controllers/` — Contains the actual logic and functions for each route (e.g., what happens when a user logs in).
* `models/` — Database schemas. Defines how the data is structured and saved in MongoDB.
* `routes/` — Defines the URLs that the frontend can call (e.g., `/api/auth`, `/api/users`, `/api/devices`).
* `middleware/` — Functions that run before a request reaches the controller (e.g., verifying if a user has a valid login token).
* `utils/` — Helper functions and utilities.
* `package.json` — Similar to `pubspec.yaml` but for the Node.js backend. It lists dependencies like `express`, `mongoose`, etc., and contains runnable scripts.

### 🔒 Environment & Ignored Files
* `.gitignore` — Tells Git which files and folders to ignore (like `node_modules` or `.env` files) so they aren't uploaded to GitHub.
* `.env.example` — A template for the environment variables required by the project.

---

## 🚀 Getting Started

Follow these steps to get the project running on your local machine.

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- [Node.js](https://nodejs.org/) installed.
- Access to a MongoDB database (local or cloud like MongoDB Atlas).

### 2. Backend Setup
1. Open a terminal and navigate to the backend folder:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Create a `.env` file in the `backend/` directory based on the `.env.example` file and fill in your database credentials and secret keys.
4. Start the development server:
   ```bash
   npm run dev
   ```
   *The server should now be running on `http://localhost:5000`.*

### 3. Frontend Setup
1. Open a new terminal and navigate to the project root.
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app on your preferred device (Chrome, Android emulator, etc.):
   ```bash
   flutter run
   ```

Happy Coding! 🚀
