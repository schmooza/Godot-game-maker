MODULAR SOUND AND MUSIC
The optional_audio.gd component is self-contained and used by Adventure, Racing and Bullet Hell.
Each game has a Sound & Music sidebar section. Select an event, import WAV/MP3/OGG, preview, stop, remove, set volume, enable, loop, and master volume.
Audio files and settings are saved separately in user://audio_<game>_*; no existing game save schema is changed.
Sound events are emitted from small _sound() calls in the editor scripts. No imported audio means silent gameplay.
Only a subset of events are currently wired: Adventure background music and damage; Racing background music, lap completion and race finish; Boss background music, player/boss firing, power-ups, win and defeat. Other event slots are ready for future wiring.
Audio assets are stored in user:// for each local installation; copy the Godot user data folder when moving a configured game to another computer.
