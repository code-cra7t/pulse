# PulseNotes QA Checklist

Run the Windows checks on a packaged or normally launched desktop build and
repeat the shared checks on Android before release.

## Auth

- [ ] Sign up with email and password.
- [ ] Log out and confirm the confirmation dialog appears.
- [ ] Log back in and confirm the notes screen loads.
- [ ] Restart the app and confirm the authenticated session is restored.

## Notes CRUD

- [ ] Create a note with a title and body.
- [ ] Edit an existing note's title and body, close it, and reopen it.
- [ ] Pin and unpin a note.
- [ ] Delete a note and confirm it disappears without an app crash.
- [ ] Repeat create and update while offline, then verify sync after reconnecting.

## Autosave

- [ ] Type in the title and confirm Saving... changes to Saved.
- [ ] Type in the body and confirm the debounced save completes.
- [ ] Close and reopen the editor and confirm the latest text remains.
- [ ] Simulate a network failure and confirm Save failed is visible.
- [ ] Restore the network, edit again, and confirm saving recovers.

## Tag Changes

- [ ] Select Work, Personal, Ideas, Study, To-Do, and Reminders in turn.
- [ ] Reopen the note after each selection and confirm it persists.
- [ ] Confirm tag filter chips are derived from tags used by real notes.
- [ ] Confirm hashtags in note text are still extracted without replacing the category.

## Image Upload

- [ ] Cancel the image picker and confirm no error appears.
- [ ] Upload an image to a new unsaved note.
- [ ] Upload an image to an existing note.
- [ ] Confirm the upload button is disabled while uploading.
- [ ] Reopen the note and confirm uploaded images remain visible.
- [ ] Disconnect the network, try an upload, and confirm a readable error appears.

## Task Parsing

- [ ] Type a line beginning with `- ` and confirm a task row appears.
- [ ] Toggle the task and confirm completion persists.
- [ ] Delete the source line and confirm the task disappears.
- [ ] Long-press a task and confirm reminder/delete actions appear.

## Smart Reminder Suggestions

- [ ] Type `tomorrow at 5pm` in normal note text.
- [ ] Type `- Call Mike tomorrow at 5pm` as a task.
- [ ] Confirm each suggestion updates while typing.
- [ ] Create each suggested reminder and confirm success feedback appears.

## Manual Reminders

- [ ] Create a future one-time reminder.
- [ ] Confirm it appears in the note reminder list only after scheduling succeeds.
- [ ] Edit its time and confirm the old notification is replaced.
- [ ] Delete it and confirm the local notification is cancelled.

## Windows Notifications

- [ ] Open a note's Reminders sheet and press Test now.
- [ ] Confirm a Windows notification appears immediately.
- [ ] Press Test in 60s, close the app, and confirm it appears after one minute.
- [ ] Create a real reminder, close the app, and confirm it fires at the selected time.
- [ ] Confirm scheduling failures show an error and do not create a Firestore reminder.
- [ ] Confirm recurring reminders are not offered on Windows V1.

## Android Notifications

- [ ] Grant Android 13+ notification permission when requested.
- [ ] Allow exact alarms when required by the device.
- [ ] Confirm a one-time notification fires with the app foregrounded, backgrounded, and closed.
- [ ] Confirm Snooze delays the notification by ten minutes.
- [ ] Confirm Dismiss removes the notification.

## Web Limitations

- [ ] Confirm notes, tags, and byte-based image uploads work in a browser.
- [ ] Confirm reminders show only in-app alerts while PulseNotes is open.
- [ ] Do not expect `zonedSchedule`, system-tray notifications, or closed-app web push.
- [ ] Track web push notifications as a future enhancement.
