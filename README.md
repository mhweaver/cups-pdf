# cups-pdf

A network print server in a container. Anything printed to it comes back as a
PDF in `./out`. To clients it looks like a plain PostScript network printer —
no scanner, no fax, no hint that it is writing PDFs.

Useful for testing print paths in apps without owning a printer, or for
"print to PDF" from machines that have no such option.

## Start it

```sh
./cups-pdf.sh
```

Builds the image on first run, then starts the container detached. Overrides:

```sh
OUT=/tmp/pdfs PORT=9631 ./cups-pdf.sh
```

| var | default | what |
|-----|---------|------|
| `OUT` | `./out` | where PDFs land |
| `PORT` | `6631` | host port (631 is taken by macOS's own cupsd) |
| `NAME` | `cups-pdf` | container name |
| `IMAGE` | `cups-pdf` | image tag |

Stop it with `docker rm -f cups-pdf`.

## Add the printer

**macOS** — System Settings → Printers & Scanners → Add → **IP** tab. All four
fields matter:

| field | value |
|-------|-------|
| Address | `localhost:6631` |
| Protocol | Internet Printing Protocol - IPP |
| Queue | `printers/Office_Printer` |
| Use | Generic PostScript Printer |

Leaving **Queue** blank is the common failure: macOS then asks for
`/ipp/print`, which CUPS does not serve, and reports "unable to communicate
with the printer". Or from the shell:

```sh
sudo lpadmin -p PDF_Out -E -v ipp://localhost:6631/printers/Office_Printer -m everywhere
```

Other clients: same URI, `ipp://<host>:6631/printers/Office_Printer`.

## Output

PDFs are named `job_<id>-<Document Title>.pdf`, so reprinting the same document
never overwrites the previous file.

Large jobs are written in place while ghostscript renders — a file that is
still growing is not finished yet. A 600 MB PostScript job takes about a
minute.

## Did it work?

```sh
docker exec cups-pdf lpstat -o
```

Empty means nothing is pending. (`lpstat -W all -o` also lists *completed*
jobs, which makes a finished job look stuck.)

```sh
docker exec cups-pdf lpstat -W completed -o
docker exec cups-pdf tail -f /var/log/cups/cups-pdf-Office_Printer_log
```

The cups-pdf log is where the truth is: `[STATUS] PDF creation successfully
finished` or `[ERROR]`.

The CUPS web UI is at http://localhost:6631 for queue and job inspection.

## Knobs

- Printer name, description and location: the `lpadmin` line in the Dockerfile.
- Output naming, target directory, permissions: `/etc/cups/cups-pdf.conf`,
  written by the Dockerfile. `Label 1` is what prefixes the job id.
- File size: ghostscript runs with `-dPDFSETTINGS=/prepress`, which keeps
  images at full resolution and can turn one document into hundreds of
  megabytes. Add a `GSCall` line to `cups-pdf.conf` with `/ebook` or
  `/printer` to trade image quality for size.

## Limits

- No authentication and no TLS. It accepts jobs from anyone who can reach the
  port — keep it on a trusted network or bound to localhost.
- Not advertised over Bonjour/mDNS (no avahi in the image, and it would not
  cross the Docker bridge anyway). Clients must be pointed at the URI.
- The disguise covers the queue, not the server: `printer-make-and-model` is
  `Generic PostScript Printer` and `device-uri` is a `socket://` address, but
  the HTTP headers and `operations-supported` still identify CUPS, as any
  shared print queue would.
