# JotCue QA Checklist

Run the Windows checks on a packaged or normally launched desktop build and
repeat the shared checks on Android before release.

## Visual review completed — August 15, 2026

- [x] Web onboarding, sign-in, and sign-up reviewed at 390 x 844 and 1440 x 900.
- [x] Notes home exercised at 320 x 700, 390 x 844 dark mode, and 699 x 900.
- [x] Adaptive navigation exercised at phone, tablet, 1100 px desktop, and 1400 px desktop widths.
- [x] Native Windows notes list, editor, settings, and About views reviewed in the release build.
- [x] Profile reviewed at 320 px, 390 px, 562 px native Windows, and embedded desktop widths.
- [x] Android launcher and splash resources verified by a successful APK build.
- [x] Web manifest, icons, title, loading splash, and install colors reviewed in the release build.
- [ ] Repeat the visual review on a physical Android device before Play submission.
- [ ] Review iPhone, iPad, and macOS builds on Apple hardware with Xcode before release.

## Auth

- [ ] Sign up with email and password.
- [ ] Sign in with Google on Android, iOS, macOS, web, and Windows.
- [ ] Cancel Google account selection and confirm the app remains usable without a false error.
- [ ] Install from Play internal testing and confirm Google Sign-In works with the Play App Signing certificate.
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

## September 8 tester regression checks

These require a physical Android device; build/unit-test success does not verify
sound, vibration, Samsung Clock or delivery during device sleep. Record Android
version, One UI version, JotCue build, notification/channel settings and battery
mode with failures. Test both an update over the previous tester build and a
fresh install. Do not clear a tester's existing notes to run these checks.

- [ ] Samsung A54: open Clock from a supported alarm suggestion, confirm the
  proposed time and task label, save it, then remove the test alarm in Clock.
- [ ] Future dates/custom recurrence that Clock cannot represent are explained;
  no incorrect time-only alarm is silently substituted.
- [ ] Choose System, Light and Dark. Open default-category and reminder-repeat
  dropdowns; inspect selected/unselected text, dialogs and interval controls.
- [ ] Select every note colour; verify a named colour indicator changes at once
  and persists after reopening. Check a narrow screen and enlarged system text.
- [ ] Create a reminder without optional exports: no calendar or Clock opens.
  Its notification uses task/note text, and the reminder title is editable.
- [ ] Run Test now and Test in 60s; verify sound/vibration against the displayed
  channel settings, and verify the settings link opens the correct channel.
- [ ] Repeat after deliberately disabling sound or vibration; the app must
  respect and accurately report the changed setting.
- [ ] Set an hourly reminder and a custom 90-minute reminder with a future first
  time. Verify the first alert and two subsequent occurrences with the app closed.
- [ ] Reopen/edit an unrelated note between interval alerts: the recurrence must
  stay anchored to its intended schedule rather than restart from app launch.
- [ ] Repeat recurrence checks with screen locked, battery saver, reboot and
  device timezone changes. Test daily/weekly wall-clock times across DST.
- [ ] Snooze one alert: it returns after ten minutes without stopping the repeat
  series. Dismiss one alert: subsequent occurrences still fire.
- [ ] Deny notification/exact-alarm permissions: show a useful error instead of
  claiming a reminder is queued. Grant access and retry without reinstalling.
- [ ] Distinguish normal app dismissal from Android Settings > Force stop. Record
  force-stop as an OS limitation and reopen the app before expecting recovery.
- [ ] Android calendar: opt in, grant calendar access and choose a writable
  calendar. Check meaningful title, date and recurrence. Export again and verify
  the same linked event is updated, without duplicates.
- [ ] Complete a one-time task/reminder: its linked Android calendar entry and
  pending notification disappear. Unrelated calendar entries remain unchanged.
- [ ] Complete a recurring occurrence: the next one remains scheduled and shown;
  Stop repeating cancels the series and removes its linked calendar entry.
- [ ] Revoke calendar permission then complete/delete an exported reminder. The
  reminder still completes, a cleanup warning appears, and cleanup retries after
  restoring access and reopening the app.
- [ ] Delete a linked event manually, then edit/complete the reminder: no unrelated
  event is touched. Legacy calendar exports remain manually managed.
- [ ] On other platforms, calendar handoff is labelled as independently managed;
  no automatic external-calendar cleanup is promised.

Voice input, semantic search and unattended-task resurfacing are planned in
`ASSISTANT_ROADMAP.md`; they are not acceptance criteria for this core-fix build.

## Web Limitations

- [ ] Confirm notes, tags, and byte-based image uploads work in a browser.
- [ ] Confirm reminders show only in-app alerts while JotCue is open.
- [ ] Do not expect `zonedSchedule`, system-tray notifications, or closed-app web push.
- [ ] Track web push notifications as a future enhancement.
