# OCTET binary envelope — draft 0.1

**Status:** experimental; wire format may change before 1.0.

## Frame layout

All multi-byte integers are unsigned, big-endian.

| Offset | Width | Field | Rule |
|---:|---:|---|---|
| 0 | 4 | Magic | ASCII `OCT1` |
| 4 | 1 | Version | `1` for this draft |
| 5 | 1 | Flags | Bit assignments reserved; unknown critical bits must be rejected by profiles |
| 6 | 4 | Payload length | Unsigned 32-bit byte count |
| 10 | N | Payload | Opaque application bytes |

Total frame size is exactly 10 + payload length. Trailing bytes are invalid. Implementations must enforce a configured maximum before allocation or processing.

## Security and robustness
- Decode from bounded input; do not trust declared lengths.
- Avoid implicit allocation in primitive codec routines.
- Reject unsupported versions and malformed frames.
- Authentication and confidentiality are transport/security-profile responsibilities, not provided by this envelope.
- Application schemas must define field meaning, required fields, unknown-field behavior and evolution rules.

## Non-goals
OCTET does not define UDP/TCP sockets, delivery guarantees, RPC method semantics, or an application API framework.
