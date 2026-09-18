FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      cups cups-pdf cups-filters \
    && rm -rf /var/lib/apt/lists/*

# ponytail: replace the shipped cups-pdf.conf instead of patching it -- cups-pdf
# 3.0.1 leaks the last config line it read into the output filename, so the file
# has to stay short. Keys: flat output dir, world-readable files, unique names.
RUN printf 'Out /output\nAnonDirName /output\nUserUMask 0000\nLabel 1\nGrp lpadmin\n' \
      > /etc/cups/cups-pdf.conf \
    && mkdir -p /output \
    && sed -i 's/^IdleExitTimeout .*/IdleExitTimeout 0/' /etc/cups/cupsd.conf

# Pose as a JetDirect-attached PostScript printer: clients see the generic
# PostScript PPD and a socket:// device-uri, never cups-pdf. The backend is
# still cups-pdf, just installed under the socket scheme.
RUN cp -p /usr/lib/cups/backend/cups-pdf /usr/lib/cups/backend/socket

# Bake the queue in by letting cupsd write its own config
RUN cupsd && sleep 2 \
    && lpadmin -p Office_Printer -v socket://127.0.0.1:9100 \
         -m drv:///sample.drv/generic.ppd \
         -D 'Office Printer' -L Office -E -o printer-is-shared=true \
    && lpadmin -d Office_Printer \
    && cupsctl --remote-admin --remote-any --share-printers \
    && kill "$(cat /run/cups/cupsd.pid)" && sleep 1 \
    && echo 'ServerAlias *' >> /etc/cups/cupsd.conf

EXPOSE 631
VOLUME /output
CMD ["/usr/sbin/cupsd", "-f"]
