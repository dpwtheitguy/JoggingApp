# RUN//PROGRAM privacy notice draft

RUN//PROGRAM is an offline Android running coach. It does not require an account
or an email address. The app does not use GPS, maps, advertising SDKs or analytics
SDKs, and it does not send workout information to a server.

The app stores your selected training programs, settings, workout attempts,
completion/repeat progress and any distance you choose to enter in a private
local database on the Android device. Distance is self-reported; the app does not
measure it. Voice instructions are bundled audio files and do not use an online
speech service during a workout.

The app requests notification permission to show workout controls, uses a
foreground service and a CPU wake lock for active timing, and can vibrate if you
enable vibration. It does not request location, microphone, contacts or storage
access. Development builds have a network permission used by Flutter tooling;
the optimized release build does not include it.

Automatic Android cloud backup and device transfer are disabled/excluded in the
app configuration. Manufacturer behavior still needs physical-device validation.
There is no cloud synchronization or in-app export in this version. Uninstalling
the app, clearing its storage or losing the device can lose the local history.
Android's app storage controls let you remove the locally stored data.

Development diagnostics record cue names, playback errors and runtime test
results. Host compatibility test logs stay on the developer's laptop and are
excluded from source control; they are not uploaded automatically. The audio lab
is present only in debug builds and does not record microphone audio.

This is a repository draft, not a published privacy-policy URL or a claim of store
approval. Before publication, the publisher must provide a contact identity,
review the shipped build and dependencies, and complete accurate store disclosures.
