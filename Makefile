BIN = gpsdate

PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

OBJS = $(patsubst %.c, %.o, $(wildcard *.c))

CFLAGS = -O3 -Wall -pedantic -Wconversion -Wcast-align
LDFLAGS = $(CFLAGS)

.PHONY: all
all: $(BIN)

$(BIN): $(OBJS)
	$(CC) $^ $(LDFLAGS) -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

.PHONY: clean
clean:
	rm -f $(OBJS) $(BIN)

.PHONY: install
install: $(BIN)
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(BIN) $(DESTDIR)$(BINDIR)/$(BIN)

.PHONY: uninstall
uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(BIN)
