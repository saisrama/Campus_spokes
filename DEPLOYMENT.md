# How to Deploy Your App to the Web

Since your app is built with Flutter, you have a few options to deploy it as a website.

## Option 1: Vercel (Easiest Manual Way)
This method is great for quick demos. You build the website on your computer and upload the files directly.

1.  **Build the Web Version**:
    Run this command in your terminal:
    ```bash
    flutter build web --release
    ```
    *(This creates a folder at `build/web` with your website files)*.

2.  **Deploy to Vercel**:
    *   Go to [vercel.com](https://vercel.com) and sign up/login.
    *   Click **"Add New..."** -> **"Project"**.
    *   Look for the **"Upload"** tab (or just drag and drop the folder).
    *   Drag your entire `build/web` folder into the upload area.
    *   Click **Deploy**.

## Option 2: Firebase Hosting (Recommended for Production)
Since you are already using Firebase for your backend, hosting your site there is often better and faster.

1.  **Initialize Hosting**:
    Run this in your terminal:
    ```bash
    firebase init hosting
    ```
    *   Select your existing Firebase project.
    *   **Public directory**: Type `build/web`.
    *   **Configure as a single-page app**: Type `Yes`.
    *   **Set up automatic builds and deploys with GitHub**: (Optional, say `No` for now).

2.  **Build and Deploy**:
    ```bash
    flutter build web --release
    firebase deploy --only hosting
    ```
    *(This automatically uploads your new build to `your-app.web.app`)*.

---

## Important Note for Web
Flutter Web apps can sometimes have issues with:
*   **CORS (Cross-Origin Resource Sharing)**: If you load images from other websites, they might not show up.
*   **Firebase Setup**: Ensure you have added a **Web App** in your Firebase Console project settings and put the config in `web/index.html` (or `firebase_options.dart` handles it).

For **Campus Spokes**, since you use `google_sign_in` and Firestore, make sure you have enabled the **Authorized Domains** in Firebase Authentication settings for your new Vercel/Firebase URL.
