# Allocation accounting checks

Run `rtk proxy powershell -NoProfile -File runtime/tests/allocation-accounting/check.ps1`.

The test links the current canonical runtime at O0 and O2 and intercepts only
the operating-system allocation boundary. A preserving resize requesting more
than 128 MiB reaches that boundary twice; both injected failures must return
Err 7 without changing the original descriptor or its value. This tests large
request admission without actually allocating the large payload.

Separate assertions reject count/stride overflow, invalid stride, live-byte
accounting overflow and live-block count overflow before an OS allocation.
A subsequent small preserving resize must retain the old value, zero its new
tail and release all byte/block charges after cleanup. Changing the expected
allocation-call count from two to three must fail at both optimization levels.

On 2026-11-25, all positive and negative controls passed against the
230,936-byte canonical runtime. Evidence:
`%TEMP%/ube allocation accounting 4271bc98-dd4d-4c03-a80b-ebd4658c3a3c`.
This does not qualify source-language frame allocation or managed collection;
those have separate gates.
