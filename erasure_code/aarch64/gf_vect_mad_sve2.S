.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_mad_sve2)
#ifndef __APPLE__
.type gf_vect_mad_sve2, %function
#endif

/* gf_vect_mad_sve2(int len, int vec, int vec_i, unsigned char *gftbls,
			   unsigned char *src, unsigned char *dest);
 */
/* arguments */
x_len		.req	x0	/* vector length in bytes */
x_vec		.req	x1	/* number of vectors in total table (unused) */
x_vec_i		.req	x2	/* index of current vector */
x_tbl_base	.req	x3	/* pointer to base of all multiplication tables */
x_src		.req	x4	/* pointer to the single source vector */
x_dest		.req	x5	/* pointer to the single destination vector */

/* returns */
w_ret		.req	w0

/* local variables */
x_pos		.req	x6	/* position offset within vectors */
x_tbl		.req	x_tbl_base /* reuse register for current table pointer */


/* vectors */
z_mask0f	.req	z0	// Mask for isolating low 4 bits of a byte

// Source data and split nibbles
z_src_in	.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z16	// Use a distinct register for clarity

// Destination data register
z_dest_inout	.req	z3

// Table registers
z_gft1_lo	.req	z6
z_gft1_hi	.req	z7

// Temporary registers for non-destructive SVE2 TBL results
z_tmp_lo_res	.req	z4
z_tmp_hi_res	.req	z5


cdecl(gf_vect_mad_sve2):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f		// z_mask0f = 0x0F0F...0F

	// Calculate pointer to the start of the tables for the current vector index
	add	x_tbl, x_tbl_base, x_vec_i, LSL #5 // x_tbl_base + vec_i * 32

	// Load the 32-byte multiplication table
	ldp	q6, q7, [x_tbl]             // z_gft1_lo, z_gft1_hi

	mov	x_pos, #0

// Loop over vector chunks of SVE vector length (VL)
.Lloopsve2_mad_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	// Prefetch destination data for the next store operation
	prfb	pldl2strm, p0, [x_dest, x_pos]

	// Load source and destination data for the current vector chunk
	ld1b	z_src_in.b,     p0/z, [x_src, x_pos]
	ld1b	z_dest_inout.b, p0/z, [x_dest, x_pos]

	// Split source bytes into low and high 4-bit nibbles
	and	z_src_lo.d, z_src_in.d, z_mask0f.d
	movprfx z_src_hi, z_src_in
	lsr	z_src_hi.b, p0/m, z_src_hi.b, #4

	// --- OPTIMIZATION: Use non-destructive SVE2 TBL instruction ---
	// Multiply source with table and add to destination
	tbl	z_tmp_lo_res.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi_res.b, {z_gft1_hi.b}, z_src_hi.b
	eor	z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d
	eor	z_dest_inout.d, z_dest_inout.d, z_tmp_lo_res.d

	// Store the final updated result for the processed chunk
	st1b	z_dest_inout.b, p0, [x_dest, x_pos]

	incb	x_pos, all, mul #1	// Increment position by one vector length
	b	.Lloopsve2_mad_vl
// End of outer loop

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret
