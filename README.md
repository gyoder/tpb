# TPB

> Pronounced `tee pee bee` or `tee pasteboard`

TPB is a super simple, small program to "tee" into my clipboard using OSC 52
codes, native objc code, and linux clipboard providers.

[Download Static Binaries](https://artifacts.gae.moe/grace/tpb)

## Usage

```sh
command | tpb
tpb path/to/file
```

---

I was somewhat fed up with `pbcopy` eating stdout making it impossible to see
the output of what I was doing without pasting it. While, yes, this could just
be a shell script, I decided to write in a systems language because its more fun
and I like the idea of it being super low latency. Originally, I was going to
write this in Rust but decided that Zig was a better fit for something like
this.
