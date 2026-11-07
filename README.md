# OCTET

**A research-oriented data representation and serialization protocol.**

OCTET defines a deterministic, versioned binary representation for structured messages exchanged by independent systems.

## Design boundaries

- Define a wire format, not a network transport.
- Specify field encoding, integer representation, lengths, versioning, optional values, and malformed-input behavior.
- Make decoding bounded and explicit about allocation.
- Support schema evolution without silently reinterpreting old messages.
- Keep RPC semantics in CALLGRAPH and socket behavior in DATAGRAM.

## Initial implementation

- Language: Zig.
- Initial scope: core byte reader/writer, primitive encodings, bounded length-prefixed fields, and conformance tests.
- Initial milestone: a written wire-format draft plus a small dependency-free codec.

## Status

Early research implementation. The format is not frozen and must not be used as a stable external protocol yet.

## Related technologies

- [CONTRACT](https://github.com/jadhavdurvesh/contract) — API framework.
- [DATAGRAM](https://github.com/jadhavdurvesh/datagram) — network transport.
- [CALLGRAPH](https://github.com/jadhavdurvesh/callgraph) — remote procedure execution.
