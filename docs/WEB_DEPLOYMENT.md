# PulseNotes Web Deployment

PulseNotes Flutter Web is deployed through Firebase Hosting.

## Firebase Hosting Config

Hosting is configured in `firebase.json` with:

- Public directory: `build/web`
- SPA rewrite: all routes go to `/index.html`
- Firebase project: `pulsenotes-c8d82` from `.firebaserc`

## Deployment Commands

```powershell
firebase login
firebase projects:list
flutter build web --release
firebase deploy --only hosting
```

## Deployment Checklist

- Test web locally with `flutter run -d chrome`.
- Build release with `flutter build web --release`.
- Deploy to Firebase Hosting with `firebase deploy --only hosting`.
- Test the deployed URL.
- Confirm login works.
- Confirm Firestore notes load.
- Confirm Firebase Storage image upload works.
- Confirm tags, settings, and profile work.
- Confirm web reminder limitations are handled safely.

## Web Reminder Limitations

PulseNotes Web currently avoids native scheduled local notifications. Web reminder support is limited to in-app reminder alerts while the app is open. Push notifications can be added later with a service worker and Firebase Cloud Messaging.

## Future Automation

GitHub Actions auto-deploy can be added later to build and deploy Firebase Hosting on pushes to the release branch. This is intentionally not configured yet.
