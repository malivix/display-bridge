# Compact monitor reading summary

Controls now places the selected monitor's previous brightness and speaker volume above
its adjustment actions. Each value has its own reading age; missing readings say not read.
The summary uses typed session observations without additional hardware queries. Backward
clock changes produce time unavailable instead of a negative or falsely fresh age.
Detailed command results remain available farther down the same scroll view.

Validation: `scripts/verify --native` passed, including 290 Python tests and native checks.
New native cases cover different feature ages, missing/cross-monitor values and backward
clock movement. A fresh isolated demo at Largest text and minimum window size showed the
selector, summary, availability and Read button together. The malformed-response scenario
retained synthetic 30%/40% values with the previous-readings label after validation failed.
No hardware commands, installation, clipboard changes or notification delivery occurred.

Follow-up: at this compact size, the detailed failure message and percentage button still
need scrolling. Make the last request's failure visible in the compact summary without
turning an old reading into a current result. Full VoiceOver behavior remains unqualified.
