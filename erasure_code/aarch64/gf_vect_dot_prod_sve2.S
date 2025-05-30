.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_vect_dot_prod_sve2, %function
#endif
/* void gf_vect_dot_prod_sve2(int len, int vlen, unsigned char *gftbls,
				unsigned char **src, unsigned char *dest);
 */

/* arguments */
x_len		.req	x0	/* vector length in bytes */
x_vec		.req	x1	/* number of source vectors (ie. data blocks) */
x_tbl		.req	x2	/* pointer to multiplication tables */
x_src		.req	x3	/* pointer to array of source vector pointers */
x_dest1		.req	x4	/* pointer to the single destination vector */

/* returns */
w_ret		.req	w0

/* local variables */
x_vec_i		.req	x5	/* source vector index counter */
x_ptr		.req	x6	/* pointer to current source vector */
x_pos		.req	x7	/* position offset within vectors */
x_tbl1		.req	x8	/* pointer to the current table */

/* vectors */
z_mask0f	.req	z0	// Mask for isolating low 4 bits of a byte

// Source data and split nibbles
z_src_in	.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z16	// Use a distinct register for clarity

// Destination accumulator
z_dest		.req	z3

// Table registers
z_gft1_lo	.req	z4
z_gft1_hi	.req	z5

// Temporary registers for non-destructive SVE2 TBL results
z_tmp_lo_res	.req	z6
z_tmp_hi_res	.req	z7

cdecl(gf_vect_dot_prod_sve2):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3		// Convert vector count to byte offset

// Outer loop: iterates over vector chunks of SVE vector length (VL)
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	z_dest.b, #0			// Clear destination accumulator
	mov	x_vec_i, #0			// Reset source vector index
	mov	x_tbl1, x_tbl			// Reset table pointer

// Inner loop: iterates through all source vectors for the current chunk
.Lloopsve2_vl_vects:
	ldr	x_ptr, [x_src, x_vec_i]		// Load current source vector pointer
	ld1b	z_src_in.b, p0/z, [x_ptr, x_pos]	// Load source data chunk

	add	x_vec_i, x_vec_i, #8		// Move to next source vector index

	// Load 32-byte GF multiplication table for the current source vector
	ldp	q4, q5, [x_tbl1], #32       // z_gft1_lo, z_gft1_hi

	// Split source bytes into low and high 4-bit nibbles
	and	z_src_lo.d, z_src_in.d, z_mask0f.d
	movprfx z_src_hi, z_src_in
	lsr	z_src_hi.b, p0/m, z_src_hi.b, #4

	// --- OPTIMIZATION: Use non-destructive SVE2 TBL instruction ---
	tbl	z_tmp_lo_res.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi_res.b, {z_gft1_hi.b}, z_src_hi.b

	// Combine results and accumulate into destination
	eor	z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d
	eor	z_dest.d, z_dest.d, z_tmp_lo_res.d

	cmp	x_vec_i, x_vec
	blt	.Lloopsve2_vl_vects
// End of inner loop

	// Store the final accumulated result for the processed chunk
	st1b	z_dest.b, p0, [x_dest1, x_pos]

	incb	x_pos, all, mul #1	// Increment position by one vector length
	b	.Lloopsve2_vl
// End of outer loop

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret
