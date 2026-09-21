# Details pause summary and keyboard focus

Keyboard inspection of the `c7449d8` demo exposed a duplicate pause message in Details:
the shared recovery summary was followed by a separate “Automation resumes at” line.
The latter bypassed the shared freshness guard. Details now uses only the shared summary,
avoiding duplicate expiry information and a resume-time promise from stale health.

Regression checks cover stale Details output: it reports out-of-date status and omits
both a resume-time assertion and a remaining-time estimate. `scripts/verify --native`
passed all 293 Python tests and native self-tests on the final source.

At Largest text/minimum window size in the existing demo, Command-2 opened Details;
selecting speaker text and pressing Command-R preserved the selection. Command-5 followed
by Tab focused the monitor selector, which retained focus through background refreshes.
These observations qualify that keyboard path in the pre-copy-change demo; they are not
full VoiceOver, appearance or live controller qualification. No hardware or installed
state changed. The final text removal was compiled and covered by presentation regression
checks; the demo was not rebuilt solely to repeat the unchanged focus behavior.
