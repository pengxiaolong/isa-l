.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_mul_sve2)
#ifndef __APPLE__
.type gf_vect_mul_sve2, %function
#endif

/* Refer to include/gf_vect_mul.h
 *
 * @param len   Length of vector in bytes. Must be aligned to 32B.
 * @param gftbl Pointer to 32-byte array of pre-calculated constants based on C.
 * @param src   Pointer to src data array. Must be aligned to 32B.
 * @param dest  Pointer to destination data array. Must be aligned to 32B.
 * @returns 0 pass, other fail
 *
 * int gf_vect_mul(int len, unsigned char *gftbl, void *src, void *dest);
 */

/* arguments */
x_len		.req	x0
x_tbl		.req	x1
x_src		.req	x2
x_dest		.req	x3
x_tmp		.req	x4

/* returns */
w_ret		.req	w0

/* local variables */
x_pos		.req	x5

/* vectors */
z_mask0f	.req	z0	// Mask for isolating low 4 bits of a byte

// Source data and split nibbles
z_src_in	.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z16	// Use a distinct register for clarity

// Destination and temporary registers
z_dest_out	.req	z3
z_tmp_lo_res	.req	z4
z_tmp_hi_res	.req	z5

// Table registers
z_gft1_lo	.req	z6
z_gft1_hi	.req	z7

cdecl(gf_vect_mul_sve2):
	// Check for 32-byte alignment
	and	x_tmp, x_len, #0x1f
	cbnz	x_tmp, .return_fail

	mov	z_mask0f.b, #0x0f		// z_mask0f = 0x0F0F...0F
	mov	x_pos, #0

	// Load the 32-byte multiplication table
	ldp	q6, q7, [x_tbl]             // z_gft1_lo, z_gft1_hi

// Loop over vector chunks of SVE vector length (VL)
.Lloopsve2_mul_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	// Load source data for the current vector chunk
	ld1b	z_src_in.b, p0/z, [x_src, x_pos]

	// Split source bytes into low and high 4-bit nibbles
	and	z_src_lo.d, z_src_in.d, z_mask0f.d
	movprfx z_src_hi, z_src_in
	lsr	z_src_hi.b, p0/m, z_src_hi.b, #4

	// --- OPTIMIZATION: Use non-destructive SVE2 TBL instruction ---
	// Table indexing for GF(2^8) multiplication
	tbl	z_tmp_lo_res.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi_res.b, {z_gft1_hi.b}, z_src_hi.b

	// Combine results via XOR for GF(2^8) addition
	eor	z_dest_out.d, z_tmp_hi_res.d, z_tmp_lo_res.d

	// Store the final result for the processed chunk
	st1b	z_dest_out.b, p0, [x_dest, x_pos]

	incb	x_pos, all, mul #1	// Increment position by one vector length
	b	.Lloopsve2_mul_vl
// End of outer loop

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret
