# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`gpsdate` is a small C command-line tool that reads date/time from a GPS receiver over a serial port (or USB CDC ACM virtual serial port) via NMEA RMC sentences (`$GPRMC`, `$GNRMC`, ...), and sets it as the local system time on Linux. It's a fork of https://github.com/adamheinrich/gpsdate with an added GPS week-rollover correction (see https://en.wikipedia.org/wiki/GPS_week_number_rollover).

## Build

```
make          # builds the `gpsdate` binary
make clean    # removes .o files and the binary
```

`Makefile` auto-discovers all `*.c` files in the repo root as objects — there is no separate test/source directory. `CFLAGS` includes `-O3 -Wall -pedantic -Wconversion -Wcast-align`; keep new code warning-clean under these flags.

There is no test suite in this repo.

## Running

```
./gpsdate [options] port
```

Setting the time requires root (`sudo ./gpsdate ...`). Notable options: `-b <baudrate>` (default 9600), `-t`/`-d <timeout seconds>` (0 = no timeout, default 10), `-r` (apply the 1024-week GPS rollover correction), `-n` (dry run — parse and print GPS time but don't set it), `-s` (always step, never slew), `-l`/`--latency <ms>` (added to the RMC time to compensate for the sentence arriving after the second it reports; default `DEFAULT_LATENCY_MS` = 30, measured ~30–32 ms against NTP). Exit code is `0` if the date was changed, `2` if not, `1` on usage/port errors.

## Architecture

Three modules, each with a `.h`/`.c` pair, wired together in `gpsdate.c`:

- **`serial_port.c`**: opens and configures the serial device (`termios` raw mode, non-blocking, baud rates 2400–921600). One function: `serial_port_open()`.
- **`nmea.c`**: a streaming, single-pass NMEA sentence parser (`nmea_parse()`). It's called repeatedly with raw bytes read from the serial fd and maintains parser state (buffer, token pointers, checksum) across calls via static variables — it is not reentrant/thread-safe by design, since `gpsdate.c` drives it from a single read loop. On each complete, checksum-valid sentence it invokes a callback with the message ID and a NULL-terminated array of field pointers.
- **`gpsdate.c`**: the driver. Main loop waits in `poll()` and reads everything available in large chunks as soon as it arrives (no sleeping — any read latency becomes error in the set time, and receivers can run at 10–20 Hz / 115200+ baud), bounded by the `-t` timeout, feeding bytes to `nmea_parse()`. The callback `process_message()` handles RMC from any talker ID with 11–13 fields (NMEA 2.3/4.1 add fields): it checks for a valid fix (`data[1] == "A"`), parses UTC time/date including fractional seconds, optionally applies `ROLLOVER_CORRECTION` (hardcoded 1024 weeks in seconds) when `-r` is passed, and then sets system time — `adjtime()` slew for offsets under `MAX_SLEW_USEC` (1 s; slewing is only ~0.5 ms/s), otherwise a `settimeofday()` step (`stime()` no longer exists in modern glibc). `SIGINT`/`SIGTERM` are handled to break the read loop cleanly.

The overall data flow is: `serial_port_open()` → raw bytes → `nmea_parse()` → parsed RMC fields → `process_message()` → `adjtime()`/`settimeofday()`.
