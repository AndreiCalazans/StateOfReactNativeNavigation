# Navigation performance comparison

Android cold start (OS `Displayed` metric) and Flashlight FPS/CPU/RAM
over the shared navigate flow. Lower cold start / CPU / RAM is better;
higher FPS is better. Device: see MEMORY.md.

| Library | Cold start (median ms) | min | max | Avg FPS | Avg CPU % | Peak RAM (MB) |
| --- | --- | --- | --- | --- | --- | --- |
| rnn | 316 | 313 | 321 | 59.8 | 31.2 | 195.3 |
| react-navigation | 358 | 338 | 472 | 59.9 | 37.8 | 213.6 |
| rnn-reanimated | 378 | 353 | 381 | 59.7 | 72.8 | 320.2 |
| navigation | 398 | 372 | 412 | 59.8 | 34.8 | 241.4 |
| expo-router | 917 | 858 | 1087 | 59.8 | 37.1 | 307.9 |

