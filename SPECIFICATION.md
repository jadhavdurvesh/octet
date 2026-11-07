# OCTET data protocol — draft 0.2

**Status:** experimental. The v0 frame envelope is not frozen.

## Frame v1
| Field | Width | Encoding |
|---|---:|---|
| Magic | 4 bytes | ASCII `OCT1` |
| Version | 1 byte | unsigned, currently 1 |
| Flags | 1 byte | bitfield, profile-defined |
| Payload length | 4 bytes | unsigned big-endian |
| Payload | N bytes | opaque profile-defined data |

The exact frame length is 10 + payload length. Trailing bytes are invalid.

## Primitive values (profile draft)
- `u8`: one byte.
- `u16`, `u32`, `u64`: unsigned big-endian.
- `i16`, `i32`, `i64`: two's-complement big-endian.
- `bytes`: u32 byte length followed by exactly that many bytes.
- `string`: u32 byte length followed by UTF-8 bytes; invalid UTF-8 is rejected.
- `array<T>`: u32 element count followed by exactly count encoded elements.
- `optional<T>`: one-byte discriminator (0 absent, 1 present), then T if present; other discriminators are invalid.

## Schema evolution rules
1. A schema has a stable identifier and major/minor version.
2. Adding an optional field may be backward-compatible only when the schema profile defines field tagging and unknown-field handling.
3. Reusing a field identifier or changing its type is breaking.
4. Unknown critical fields are rejected; unknown non-critical fields may be skipped only when length-delimited.
5. Implementations enforce maximum frame, string, array and nesting limits before allocation.
6. Canonical encoding is required for signed or hashed payload profiles.

## Security
OCTET provides no encryption, peer authentication, replay protection or delivery guarantees. Those belong to security and transport profiles.
