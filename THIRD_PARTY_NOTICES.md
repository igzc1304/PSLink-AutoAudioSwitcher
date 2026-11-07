# Third-party acknowledgments

The hardware research and community documentation at
[Jprnp/pslink-libusb](https://github.com/Jprnp/pslink-libusb) by João Rodrigues
informed the PS Link adapter status investigation.

Its upstream license is MIT (copyright (c) 2026 João Rodrigues).
See the upstream [LICENSE](https://github.com/Jprnp/pslink-libusb/blob/main/LICENSE)
for its complete terms and copyright notice.

This repository does **not** bundle the pslink-libusb binary, its WinUSB replacement
driver workflow, or the Sony PC software. The status bytes were also verified
on an actual `054C:0ECC` adapter independently during development.

The Windows API signatures and GUIDs used here describe public OS integration
points. They are not Sony firmware or Sony proprietary binaries.

## Upstream license text

MIT License

Copyright (c) 2026 João Rodrigues (Jprnp)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.