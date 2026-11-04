# Emacs report draft: process-attributes CPU times are ~42 times too small on Apple silicon

Draft for the Emacs bug tracker: `M-x report-emacs-bug`, or mail to
bug-gnu-emacs@gnu.org. Not sent; the owner sends it (O-80, D-165, H-24).
Reproduction: `process_attributes_cpu_repro.el` in this directory.

---

**Subject:** 31.1; process-attributes: utime, stime and time about 42 times too small on
Apple silicon (Mach ticks read as nanoseconds)

### Environment
- GNU Emacs 31.1 (MacPorts `emacs-app`, aarch64-apple-darwin27.0.0, NS), macOS 27.0.1,
  Apple M3 Pro (`hw.tbfrequency` 24000000).

### What happens
On Apple silicon, the `utime`, `stime` and `time` entries of `process-attributes`
are about 41.7 times smaller than the CPU time the process used. `proced`'s TIME
column and any Lisp that measures another process's CPU through `process-attributes`
are off by the same factor. `current-cpu-time` (and `get-internal-run-time`) for
Emacs itself are right.

### Reproduction (emacs -Q)
`emacs -Q --batch -l process_attributes_cpu_repro.el` busy-loops for one second and
compares `current-cpu-time` with the `time` attribute of `(process-attributes
(emacs-pid))`:

```
GNU Emacs 31.1 (build 2, aarch64-apple-darwin27.0.0, NS appkit-2775.10 Version 27.0.1 (Build 26A434)), aarch64-apple-darwin27.0.0
1 s of busy work: current-cpu-time 1.001 s, process-attributes 0.024 s, ratio 41.7
```

The same holds for other processes: a child that burned 1.0 s of CPU read as
0.027 s.

### Cause
In `src/sysdep.c`, `system_process_attributes` for Darwin, the
`HAVE_RUSAGE_INFO_CURRENT` branch (added for bug#48548) takes `ri_user_time` and
`ri_system_time` from `proc_pid_rusage` as nanoseconds:

```c
struct timespec utime = make_timespec (ri.ri_user_time / TIMESPEC_HZ,
                                       ri.ri_user_time % TIMESPEC_HZ);
```

Those fields count Mach absolute time units. On Intel Macs the timebase is 1/1, so
they happen to be nanoseconds; on Apple silicon it is 125/3 (a 24 MHz timebase), so
one unit is 41.67 ns, which is the factor seen above. Apple's porting notes
("Addressing Architectural Differences in Your macOS Code") warn against treating
Mach absolute time as nanoseconds. osquery (issue 7459, fixed in pull request 7473)
and gosigar (pull request 191) had the same bug with the same fields.

### A possible fix (not compiled or tested here)
Scale by `mach_timebase_info` before splitting into seconds and nanoseconds:

```c
#include <mach/mach_time.h>
...
#if HAVE_RUSAGE_INFO_CURRENT
  rusage_info_current ri;
  if (proc_pid_rusage(proc_id, RUSAGE_INFO_CURRENT, (rusage_info_t *) &ri) == 0)
    {
      /* ri_user_time and ri_system_time count Mach absolute time
         units, nanoseconds only where the timebase is 1/1.  */
      static mach_timebase_info_data_t timebase;
      if (timebase.denom == 0)
        mach_timebase_info (&timebase);
      uint64_t user_ns = ri.ri_user_time * timebase.numer / timebase.denom;
      uint64_t system_ns = ri.ri_system_time * timebase.numer / timebase.denom;
      struct timespec utime = make_timespec (user_ns / TIMESPEC_HZ,
                                             user_ns % TIMESPEC_HZ);
      struct timespec stime = make_timespec (system_ns / TIMESPEC_HZ,
                                             system_ns % TIMESPEC_HZ);
      ...
```

The multiplication overflows only after about 195 years of CPU time at numer 125.
